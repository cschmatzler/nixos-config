#!/usr/bin/env fish

function open_local_shell
    exec "$HERDR_SANDBOX_HOST_SHELL" -l
end

if not set -q HERDR_WORKSPACE_ID
    open_local_shell
end

set -l workspace_json ($HERDR_SANDBOX_HERDR workspace get "$HERDR_WORKSPACE_ID" 2>/dev/null)
if test $status -ne 0
    open_local_shell
end
set -l is_linked_worktree (printf '%s' "$workspace_json" | "$HERDR_SANDBOX_JQ" -r '.result.workspace.worktree.is_linked_worktree // false')
if test "$is_linked_worktree" != true
    open_local_shell
end

set -l checkout (printf '%s' "$workspace_json" | "$HERDR_SANDBOX_JQ" -r '.result.workspace.worktree.checkout_path')
set checkout (realpath "$checkout")
set -l repo_root (printf '%s' "$workspace_json" | "$HERDR_SANDBOX_JQ" -r '.result.workspace.worktree.repo_root')
set repo_root (realpath "$repo_root")
set -l branch ("$HERDR_SANDBOX_GIT" -C "$checkout" branch --show-current)
"$HERDR_SANDBOX_HERDR" workspace rename "$HERDR_WORKSPACE_ID" (basename "$checkout") >/dev/null
if test -z "$branch"
    echo "[herdr-sandbox] detached worktrees are not supported" >&2
    exit 1
end
set -l digest (printf '%s' "$checkout" | "$HERDR_SANDBOX_SHA256SUM" | string split ' ')[1]
set -l sandbox "herdr-"(string sub -s 1 -l 20 "$digest")
set -l state_directory "$HERDR_SANDBOX_STATE_DIRECTORY"
mkdir -p "$state_directory/registrations" "$state_directory/provisioned"
chmod 700 "$state_directory" "$state_directory/registrations" "$state_directory/provisioned"

function store_sandbox_secret
    set -l errors "$HERDR_SANDBOX_STATE_DIRECTORY/secret-errors-"(random)".log"
    command $argv >/dev/null 2>"$errors"
    set -l result $status
    if test $result -ne 0
        cat "$errors" >&2
    end
    rm -f "$errors"
    return $result
end

# Everything below the attach exec runs only until the sandbox is provisioned
# and its guest state is current; a routine pane attach costs one sbx exec.
# After `sbx rm <sandbox>`, also remove $state_directory/provisioned/<sandbox>.
set -l provisioned "$state_directory/provisioned/$sandbox"

if not test -f "$provisioned"
    set -l sandbox_exists ("$HERDR_SANDBOX_SBX" ls --json | "$HERDR_SANDBOX_JQ" -r --arg name "$sandbox" '.sandboxes | any(.name == $name)')
    if test "$sandbox_exists" != true
        set -l mounts "/nix:ro"
        for cache in \
            "$HERDR_SANDBOX_HOST_HOME/.pi/agent/npm" \
            "$HERDR_SANDBOX_HOST_HOME/.pi/agent/git" \
            "$HERDR_SANDBOX_HOST_HOME/.cache/nix" \
            "$HERDR_SANDBOX_HOST_HOME/.cache/ms-playwright"
            if test -e "$cache"
                set -a mounts "$cache:ro"
            end
        end
        # Secrets are global: sbx scrypt-decrypts every store entry on each
        # CLI invocation, so per-sandbox copies make every exec slower.
        set -l stored_secrets ("$HERDR_SANDBOX_SBX" secret ls 2>/dev/null | string collect)
        if test -f "$HERDR_SANDBOX_SUPERMEMORY_KEY"; and not string match -qr '(^|\s)herdr-supermemory\s' -- "$stored_secrets"
            set -l supermemory_key (string trim <"$HERDR_SANDBOX_SUPERMEMORY_KEY")
            store_sandbox_secret "$HERDR_SANDBOX_SBX" secret set-custom \
                --host api.supermemory.ai \
                --env SUPERMEMORY_API_KEY \
                --placeholder herdr-supermemory \
                --value "$supermemory_key"; or exit 1
        end
        "$HERDR_SANDBOX_SBX" create --quiet --clone \
            --name "$sandbox" \
            --cpus "$HERDR_SANDBOX_CPUS" \
            --memory "$HERDR_SANDBOX_MEMORY" \
            --kit "$HERDR_SANDBOX_KIT" \
            shell "$repo_root" $mounts
        if test $status -ne 0
            set sandbox_exists ("$HERDR_SANDBOX_SBX" ls --json | "$HERDR_SANDBOX_JQ" -r --arg name "$sandbox" '.sandboxes | any(.name == $name)')
            test "$sandbox_exists" = true; or exit 1
        else
            if not "$HERDR_SANDBOX_SBX" exec -u agent "$sandbox" \
                    git switch --track -c "$branch" "origin/$branch"
                "$HERDR_SANDBOX_SBX" rm --force "$sandbox" >/dev/null
                exit 1
            end
            if not string match -q '*github*' -- "$stored_secrets"
                if set -l github_token ("$HERDR_SANDBOX_GH" auth token 2>/dev/null)
                    printf '%s' "$github_token" | store_sandbox_secret \
                        "$HERDR_SANDBOX_SBX" secret set github; or exit 1
                end
            end
        end
    end
end

set -l registration "$state_directory/registrations/$sandbox.json"
set -l token
if test -f "$registration"
    set token ("$HERDR_SANDBOX_JQ" -r '.token // empty' "$registration")
end
if not string match -qr '^[a-f0-9]{64}$' -- "$token"
    set token ("$HERDR_SANDBOX_OPENSSL" rand -hex 32)
end
set -l temporary_registration "$registration."(random)
"$HERDR_SANDBOX_JQ" -n \
    --arg workspaceId "$HERDR_WORKSPACE_ID" \
    --arg sandboxName "$sandbox" \
    --arg checkoutPath "$checkout" \
    --arg token "$token" \
    '{workspaceId: $workspaceId, sandboxName: $sandboxName, checkoutPath: $checkoutPath, token: $token}' \
    >"$temporary_registration"
chmod 600 "$temporary_registration"
mv -f "$temporary_registration" "$registration"

# Sync credentials and the guest-side scripts only when their content changes.
# The stamp covers the kit store path, so guest scripts in existing sandboxes
# update without recreating them or bumping the kit version.
set -l guest_home_paths
for relative in \
    .pi/agent/auth.json \
    .pi/agent/mcp-auth.json \
    .pi/agent/mcp-oauth \
    .pi/agent/trust.json \
    .pi/agent/extensions/herdr-agent-state.ts \
    .claude/.credentials.json
    if test -e "$HERDR_SANDBOX_HOST_HOME/$relative"
        set -a guest_home_paths "$relative"
    end
end
set -l sync_state "$HERDR_SANDBOX_KIT"
for relative in $guest_home_paths
    set -a sync_state (stat -c '%n %Y' "$HERDR_SANDBOX_HOST_HOME/$relative")
end
set -l sync_digest (printf '%s\n' $sync_state | "$HERDR_SANDBOX_SHA256SUM" | string split ' ')[1]
if test "$sync_digest" != "$(cat $provisioned 2>/dev/null)"
    "$HERDR_SANDBOX_TAR" --mode=u+rwX -cf - \
        -C "$HERDR_SANDBOX_KIT/files/home" .local .config \
        -C "$HERDR_SANDBOX_HOST_HOME" $guest_home_paths |
        "$HERDR_SANDBOX_SBX" exec -i -u agent "$sandbox" tar -xf - -C /home/agent
    or exit 1
    printf '%s' "$sync_digest" >"$provisioned"
end

set -l terminal xterm-256color
if set -q TERM
    set terminal "$TERM"
end
set -l exec_env \
    -e "HERDR_ENV=1" \
    -e "HERDR_WORKSPACE_ID=$HERDR_WORKSPACE_ID" \
    -e "HERDR_TAB_ID=$HERDR_TAB_ID" \
    -e "HERDR_PANE_ID=$HERDR_PANE_ID" \
    -e "HERDR_SANDBOX_TOKEN=$token" \
    -e "HERDR_SANDBOX_BRIDGE_URL=http://host.docker.internal:$HERDR_SANDBOX_LISTEN_PORT" \
    -e "HERDR_HOST_PROFILE=$HERDR_SANDBOX_HOST_PROFILE" \
    -e "HERDR_HOST_HOME_FILES=$HERDR_SANDBOX_HOME_FILES" \
    -e "HERDR_HOST_NAME=$HERDR_SANDBOX_HOST_NAME" \
    -e "HERDR_NIX=$HERDR_SANDBOX_NIX" \
    -e "HERDR_HOST_HOME=$HERDR_SANDBOX_HOST_HOME" \
    -e "HERDR_CHECKOUT=$checkout" \
    -e "HERDR_REPO_ROOT=$repo_root" \
    -e "TERM=$terminal" \
    -e "LANG=C.UTF-8"
if set -q COLORTERM
    set -a exec_env -e "COLORTERM=$COLORTERM"
end

# The pane-shell wrapper execs sbx through a fish-named path so Herdr treats
# the attached pane as an available shell for `agent.start`. The guest script
# bind-mounts the checkout and drops into it, so no -w is passed here.
exec "$HERDR_SANDBOX_SBX_PANE_SHELL" exec -it -u agent $exec_env \
    "$sandbox" "$HERDR_SANDBOX_HOST_PROFILE/bin/fish" \
    /home/agent/.local/bin/herdr-sandbox-fish
