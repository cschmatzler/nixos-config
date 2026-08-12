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
set -l runtime_directory "$HERDR_SANDBOX_RUNTIME_DIRECTORY"
set -l known_hosts "$state_directory/known-hosts"
set -l target "agent@vsock-mux$HERDR_SANDBOX_SYSTEM_STATE/workspaces/$sandbox/run/notify.vsock"
mkdir -p \
    "$state_directory/capabilities" \
    "$state_directory/registrations" \
    "$state_directory/sync" \
    "$runtime_directory/locks" \
    "$runtime_directory/masters" \
    "$runtime_directory/state"
chmod 700 \
    "$state_directory" \
    "$state_directory/capabilities" \
    "$state_directory/registrations" \
    "$state_directory/sync" \
    "$runtime_directory" \
    "$runtime_directory/locks" \
    "$runtime_directory/masters" \
    "$runtime_directory/state"
touch "$known_hosts"
chmod 600 "$known_hosts"

set -l control_socket "$runtime_directory/masters/$sandbox"
if test (string length -- "$control_socket") -gt 100
    echo "[herdr-sandbox] SSH control socket path is too long" >&2
    exit 1
end
set -l ssh_options \
    -F /dev/null \
    -o "ProxyCommand $HERDR_SANDBOX_SSH_PROXY %h %p" \
    -o ProxyUseFdpass=yes \
    -o "IdentityFile=$HERDR_SANDBOX_SSH_KEY" \
    -o IdentitiesOnly=yes \
    -o "UserKnownHostsFile=$known_hosts" \
    -o "HostKeyAlias=$sandbox" \
    -o StrictHostKeyChecking=accept-new \
    -o LogLevel=ERROR \
    -o ConnectTimeout=3 \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=2 \
    -o ControlMaster=auto \
    -o ControlPersist=600 \
    -o "ControlPath=$control_socket"

set -l registration "$state_directory/registrations/$sandbox.json"
set -l capability_file "$state_directory/capabilities/$sandbox"
set -l token (cat "$capability_file" 2>/dev/null)
if not string match -qr '^[a-f0-9]{64}$' -- "$token"
    set -l temporary_capability "$capability_file."(random)
    "$HERDR_SANDBOX_OPENSSL" rand -hex 32 >"$temporary_capability"
    chmod 600 "$temporary_capability"
    ln "$temporary_capability" "$capability_file" 2>/dev/null
    rm -f "$temporary_capability"
    set token (cat "$capability_file")
end
if not string match -qr '^[a-f0-9]{64}$' -- "$token"
    echo "[herdr-sandbox] invalid capability state for $sandbox" >&2
    exit 1
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

set -l credential_paths \
    .pi/agent/auth.json \
    .pi/agent/mcp-auth.json \
    .pi/agent/mcp-oauth \
    .pi/agent/trust.json \
    .pi/agent/extensions/herdr-agent-state.ts \
    .claude/.credentials.json
set -l runtime_sync_state "$HERDR_SANDBOX_GUEST_HOME" \
    (find "$HERDR_SANDBOX_PROXY_CA_CERT" -printf '%p %T@ %s\n' 2>/dev/null)
set -l runtime_sync_digest (printf '%s\n' $runtime_sync_state |
    "$HERDR_SANDBOX_SHA256SUM" | string split ' ')[1]
set -l credential_sync_state "$token"
for relative in $credential_paths
    if test -e "$HERDR_SANDBOX_HOST_HOME/$relative"
        set -a credential_sync_state (find "$HERDR_SANDBOX_HOST_HOME/$relative" \
            -printf '%p %T@ %s %l\n' 2>/dev/null)
    end
end
set -l credential_sync_digest (printf '%s\n' $credential_sync_state |
    "$HERDR_SANDBOX_SHA256SUM" | string split ' ')[1]
set -l sync_digest (printf '%s\0%s' "$runtime_sync_digest" "$credential_sync_digest" |
    "$HERDR_SANDBOX_SHA256SUM" | string split ' ')[1]

set -l zero_fingerprint (string repeat -n 64 0)
set -g devenv_fingerprint "$zero_fingerprint"
set -g dependency_fingerprint "$zero_fingerprint"
set -g project_fingerprint "$zero_fingerprint"
set -g encoded_environment ""

if not string match -qr '^[A-Za-z0-9:_-]+$' -- "$HERDR_PANE_ID"
    echo "[herdr-sandbox] invalid pane id" >&2
    exit 1
end
set -l terminal xterm-256color
set -q TERM; and set terminal "$TERM"
set -l color_terminal ""
set -q COLORTERM; and set color_terminal "$COLORTERM"
function build_pane_environment
    set -l pane_json ("$HERDR_SANDBOX_JQ" -cn \
        --arg HERDR_ENV 1 \
        --arg HERDR_WORKSPACE_ID "$HERDR_WORKSPACE_ID" \
        --arg HERDR_TAB_ID "$HERDR_TAB_ID" \
        --arg HERDR_PANE_ID "$HERDR_PANE_ID" \
        --arg HERDR_HOST_PROFILE "$HERDR_SANDBOX_HOST_PROFILE" \
        --arg HERDR_HOST_HOME_FILES "$HERDR_SANDBOX_HOME_FILES" \
        --arg HERDR_HOST_NAME "$HERDR_SANDBOX_HOST_NAME" \
        --arg HERDR_NIX "$HERDR_SANDBOX_NIX" \
        --arg HERDR_HOST_HOME "$HERDR_SANDBOX_HOST_HOME" \
        --arg HERDR_CHECKOUT "$checkout" \
        --arg HERDR_REPO_ROOT "$repo_root" \
        --arg HERDR_SANDBOX_BROKER_PORT "$HERDR_SANDBOX_BROKER_PORT" \
        --arg HERDR_SANDBOX_EGRESS_PORT "$HERDR_SANDBOX_EGRESS_PORT" \
        --arg HERDR_SANDBOX_CREDENTIAL_TOKEN "$HERDR_SANDBOX_CREDENTIAL_TOKEN" \
        --arg HERDR_DEVENV_CACHE_FINGERPRINT "$devenv_fingerprint" \
        --arg HERDR_DEPENDENCY_CACHE_FINGERPRINT "$dependency_fingerprint" \
        --arg TERM "$terminal" \
        --arg LANG C.UTF-8 \
        --arg COLORTERM "$color_terminal" \
        '$ARGS.named')
    or return 1
    set -g encoded_environment (printf '%s' "$pane_json" | "$HERDR_SANDBOX_BASE64" -w0)
end

function unit_identity --argument unit
    set -l properties ("$HERDR_SANDBOX_SYSTEMCTL" show "$unit" \
        --property ActiveState --property SubState --property InvocationID 2>/dev/null)
    set -l active (string replace 'ActiveState=' '' -- (string match 'ActiveState=*' $properties))
    set -l substate (string replace 'SubState=' '' -- (string match 'SubState=*' $properties))
    set -l invocation (string replace 'InvocationID=' '' -- (string match 'InvocationID=*' $properties))
    if test "$active" = active; and test "$substate" = running; and string match -qr '^[a-f0-9]{32}$' -- "$invocation"
        printf '%s' "$invocation"
        return 0
    end
    return 1
end

function guest_container_ready
    test ("$HERDR_SANDBOX_SSH" $ssh_options "$target" \
        'sudo -n machinectl show herdr-workspace --property State --value' \
        2>/dev/null | string trim) = running
end

function load_state_fingerprints
    set -l values ("$HERDR_SANDBOX_JQ" -er \
        '[.devenv, .dependencies, .project] | @tsv' "$runtime_state" 2>/dev/null)
    set -l fields (string split \t -- "$values")
    if test (count $fields) -ne 3
        return 1
    end
    for value in $fields
        string match -qr '^[a-f0-9]{64}$' -- "$value"; or return 1
    end
    set -g devenv_fingerprint "$fields[1]"
    set -g dependency_fingerprint "$fields[2]"
    set -g project_fingerprint "$fields[3]"
    build_pane_environment
end

function attach_pane --argument mode
    "$HERDR_SANDBOX_SYSTEMCTL" start "herdr-microvm-attach@$sandbox.service"; or return 1
    set -l remote_argv \
        sudo -n machinectl --quiet shell agent@herdr-workspace \
        "$HERDR_SANDBOX_HOST_PROFILE/bin/fish" \
        /home/agent/.local/bin/herdr-sandbox-enter \
        "$encoded_environment" \
        "$HERDR_SANDBOX_HOST_PROFILE" \
        "$mode"
    set -l remote_command (string join -- ' ' (string escape -- $remote_argv))
    exec "$HERDR_SANDBOX_PANE_SSH" -tt $ssh_options "$target" "$remote_command"
end

function prepare_project
    set -l remote_argv \
        sudo -n systemd-run --quiet --wait --pipe --collect \
        --machine=herdr-workspace --uid=agent \
        "$HERDR_SANDBOX_HOST_PROFILE/bin/fish" \
        /home/agent/.local/bin/herdr-sandbox-enter \
        "$encoded_environment" \
        "$HERDR_SANDBOX_HOST_PROFILE" \
        prepare
    set -l remote_command (string join -- ' ' (string escape -- $remote_argv))
    "$HERDR_SANDBOX_SSH" $ssh_options "$target" "$remote_command"
end

set -l unit "herdr-microvm@$sandbox.service"
set -l runtime_state "$runtime_directory/state/$sandbox.json"
set -l invocation (unit_identity "$unit")
if test $status -eq 0; and test -r "$runtime_state"
    set -l state_matches ("$HERDR_SANDBOX_JQ" -er \
        --arg invocation "$invocation" \
        --arg sync "$sync_digest" \
        --arg workspace "$HERDR_WORKSPACE_ID" '
          .invocation == $invocation and
          .sync == $sync and
          .workspace == $workspace
        ' "$runtime_state" 2>/dev/null)
    if test "$state_matches" = true; and load_state_fingerprints; and guest_container_ready
        attach_pane attach
    end
end

# Serialize the slow path. A waiter rechecks the fast-path state after the owner finishes.
set -l slow_lock "$runtime_directory/locks/$sandbox"
set -l owns_slow_lock false
for _attempt in (seq 1200)
    if mkdir "$slow_lock" 2>/dev/null
        printf '%s' "$fish_pid" >"$slow_lock/owner"
        set owns_slow_lock true
        break
    end
    set -l owner (cat "$slow_lock/owner" 2>/dev/null)
    if string match -qr '^[0-9]+$' -- "$owner"; and not kill -0 "$owner" 2>/dev/null
        set -l stale "$slow_lock.stale.$fish_pid"
        if mv "$slow_lock" "$stale" 2>/dev/null
            rm -rf "$stale"
            continue
        end
    end
    sleep 0.1
end
if test "$owns_slow_lock" != true
    echo "[herdr-sandbox] timed out waiting for workspace preparation" >&2
    exit 1
end
set -g __herdr_slow_lock "$slow_lock"
function cleanup_slow_lock --on-event fish_exit
    test -n "$__herdr_slow_lock"; and rm -rf "$__herdr_slow_lock" 2>/dev/null
end

set -l cache_json ("$HERDR_SANDBOX_CACHE" fingerprint \
    --root "$checkout" \
    --repo-root "$repo_root" \
    --profile "$HERDR_SANDBOX_HOST_PROFILE" 2>/dev/null)
set -l fingerprint_status $status
if test $fingerprint_status -eq 0
    set -g devenv_fingerprint (printf '%s' "$cache_json" | "$HERDR_SANDBOX_JQ" -r '.devenv // empty')
    set -g dependency_fingerprint (printf '%s' "$cache_json" | "$HERDR_SANDBOX_JQ" -r '.dependencies // empty')
    set -g project_fingerprint (printf '%s' "$cache_json" | "$HERDR_SANDBOX_JQ" -r '.project // empty')
end
set -l template_eligible true
for name in devenv_fingerprint dependency_fingerprint project_fingerprint
    if not string match -qr '^[a-f0-9]{64}$' -- "$$name"; or test "$$name" = "$zero_fingerprint"
        set template_eligible false
        set $name "$zero_fingerprint"
    end
end
build_pane_environment; or exit 1
set -l template_key (printf '%s\0%s' "$project_fingerprint" "$HERDR_SANDBOX_TEMPLATE_CONTEXT" |
    "$HERDR_SANDBOX_SHA256SUM" | string split ' ')[1]
set -l request_directory "$state_directory/requests"
set -l request "$request_directory/$sandbox.json"
mkdir -p "$request_directory"
chmod 700 "$request_directory"
set -l temporary_request "$request."(random)
"$HERDR_SANDBOX_JQ" -n \
    --arg templateKey "$template_key" \
    --arg project "$project_fingerprint" \
    --argjson templateEligible "$template_eligible" \
    '{templateKey: $templateKey, project: $project, templateEligible: $templateEligible}' >"$temporary_request"
chmod 600 "$temporary_request"
mv -f "$temporary_request" "$request"

if not "$HERDR_SANDBOX_SYSTEMCTL" is-active --quiet "$unit"
    "$HERDR_SANDBOX_SYSTEMCTL" start "$unit"; or begin
        echo "[herdr-sandbox] failed to start $sandbox" >&2
        exit 1
    end
end
"$HERDR_SANDBOX_SYSTEMCTL" start "herdr-microvm-access@$sandbox.service"; or begin
    echo "[herdr-sandbox] failed to publish the transport socket for $sandbox" >&2
    exit 1
end

set -l ssh_ready false
for _attempt in (seq 150)
    if "$HERDR_SANDBOX_SSH" $ssh_options "$target" true >/dev/null 2>&1
        set ssh_ready true
        break
    end
    sleep 0.1
end
if test "$ssh_ready" != true
    echo "[herdr-sandbox] SSH did not become ready for $sandbox" >&2
    exit 1
end
if not test -r "$HERDR_SANDBOX_PROXY_CA_CERT"
    echo "[herdr-sandbox] egress proxy CA is unavailable" >&2
    exit 1
end
cat "$HERDR_SANDBOX_PROXY_CA_CERT" |
    "$HERDR_SANDBOX_SSH" $ssh_options "$target" 'sudo -n herdr-guest-provision proxy-ca'
or exit 1

set -l origin_url ("$HERDR_SANDBOX_GIT" -C "$repo_root" remote get-url origin 2>/dev/null)
if string match -qr '^git@github\.com:' -- "$origin_url"
    set origin_url (string replace -r '^git@github\.com:' 'https://github.com/' -- "$origin_url")
end
"$HERDR_SANDBOX_JQ" -n \
    --arg checkoutPath "$checkout" \
    --arg branch "$branch" \
    --arg originUrl "$origin_url" \
    '{checkoutPath: $checkoutPath, branch: $branch, originUrl: $originUrl}' |
    "$HERDR_SANDBOX_SSH" $ssh_options "$target" 'sudo -n herdr-guest-provision metadata'
or exit 1

if not "$HERDR_SANDBOX_SSH" $ssh_options "$target" 'sudo -n herdr-guest-provision seeded' >/dev/null 2>&1
    set -l bundle (mktemp "$state_directory/sync/$sandbox.bundle.XXXXXX")
    "$HERDR_SANDBOX_GIT" -C "$repo_root" bundle create "$bundle" --all; or exit 1
    "$HERDR_SANDBOX_SSH" $ssh_options "$target" 'sudo -n herdr-guest-provision seed' <"$bundle"
    set -l seed_status $status
    rm -f "$bundle"
    test $seed_status -eq 0; or exit 1
end

if test "$project_fingerprint" != "$zero_fingerprint"; and \
        not "$HERDR_SANDBOX_SSH" $ssh_options "$target" \
            "sudo -n herdr-guest-provision cache-ready $devenv_fingerprint $dependency_fingerprint" \
            >/dev/null 2>&1
    set -l cache_parent (mktemp -d "$state_directory/sync/$sandbox.cache.XXXXXX")
    set -l cache_directory "$cache_parent/payload"
    set -l snapshot_json ("$HERDR_SANDBOX_CACHE" snapshot \
        --root "$checkout" \
        --repo-root "$repo_root" \
        --profile "$HERDR_SANDBOX_HOST_PROFILE" \
        --output "$cache_directory" 2>/dev/null)
    if test $status -eq 0; and test (printf '%s' "$snapshot_json" | "$HERDR_SANDBOX_JQ" -r '.reused // false') = true
        "$HERDR_SANDBOX_SSH" $ssh_options "$target" \
            'sudo -n herdr-guest-provision stop-container'; or exit 1
        set -l cache_archive "$state_directory/sync/$sandbox.cache.tar.zst"
        "$HERDR_SANDBOX_TAR" --create --format=posix --numeric-owner \
            --owner=0 --group=0 --mode='u+rwX,go-rwx' \
            --directory "$cache_directory" . |
            "$HERDR_SANDBOX_ZSTD" -1 -T0 -q -o "$cache_archive"
        or exit 1
        set -l archive_digest ("$HERDR_SANDBOX_SHA256SUM" "$cache_archive" | string split ' ')[1]
        set -l expanded_bytes (printf '%s' "$snapshot_json" | "$HERDR_SANDBOX_JQ" -er '.expandedBytes')
        "$HERDR_SANDBOX_SSH" $ssh_options "$target" \
            "sudo -n herdr-guest-provision cache-seed $devenv_fingerprint $dependency_fingerprint $archive_digest $expanded_bytes" \
            <"$cache_archive"
        or exit 1
        rm -f "$cache_archive"
    end
    rm -rf "$cache_parent"
end

"$HERDR_SANDBOX_SSH" $ssh_options "$target" 'sudo -n herdr-guest-provision start'; or exit 1
"$HERDR_SANDBOX_SSH" $ssh_options "$target" 'sudo -n herdr-guest-provision ready'; or exit 1
set -l template_candidate false
set -l candidate_file "$HERDR_SANDBOX_SYSTEM_STATE/workspaces/$sandbox/template-candidate"
set -l attached_file "$HERDR_SANDBOX_SYSTEM_STATE/workspaces/$sandbox/attached"
if test "$template_eligible" = true; and test -f "$candidate_file"; and not test -e "$attached_file"
    set template_candidate true
end

function sync_runtime_home
    set -l guest_digest ("$HERDR_SANDBOX_SSH" $ssh_options "$target" \
        'sudo -n systemd-run --quiet --wait --pipe --collect --machine=herdr-workspace --uid=agent /usr/bin/cat /home/agent/.local/state/herdr-sandbox/runtime-sync-digest' \
        2>/dev/null | string collect)
    if test "$guest_digest" = "$runtime_sync_digest"
        return 0
    end
    set -l directory (mktemp -d "$state_directory/sync/$sandbox.runtime.XXXXXX")
    mkdir -p "$directory/home"
    cp -a "$HERDR_SANDBOX_GUEST_HOME/." "$directory/home/"
    chmod -R u+w "$directory/home"
    mkdir -p "$directory/home/.local/state/herdr-sandbox"
    cp "$HERDR_SANDBOX_PROXY_CA_CERT" "$directory/home/.local/state/herdr-sandbox/proxy-ca.crt"
    chmod 600 "$directory/home/.local/state/herdr-sandbox/proxy-ca.crt"
    printf '%s' "$runtime_sync_digest" >"$directory/home/.local/state/herdr-sandbox/runtime-sync-digest"
    "$HERDR_SANDBOX_TAR" -cf - -C "$directory/home" . |
        "$HERDR_SANDBOX_SSH" $ssh_options "$target" \
            'sudo -n systemd-run --quiet --wait --pipe --collect --machine=herdr-workspace --uid=agent /usr/bin/tar -xf - -C /home/agent'
    set -l result $status
    rm -rf "$directory"
    return $result
end

function sync_credentials
    set -l guest_digest ("$HERDR_SANDBOX_SSH" $ssh_options "$target" \
        'sudo -n systemd-run --quiet --wait --pipe --collect --machine=herdr-workspace --uid=agent /usr/bin/cat /home/agent/.local/state/herdr-sandbox/credential-sync-digest' \
        2>/dev/null | string collect)
    if test "$guest_digest" = "$credential_sync_digest"
        return 0
    end
    set -l directory (mktemp -d "$state_directory/sync/$sandbox.credentials.XXXXXX")
    mkdir -p "$directory/home/.local/state/herdr-sandbox"
    for relative in $credential_paths
        if test -e "$HERDR_SANDBOX_HOST_HOME/$relative"
            mkdir -p "$directory/home/"(dirname "$relative")
            cp -a "$HERDR_SANDBOX_HOST_HOME/$relative" "$directory/home/$relative"
        end
    end
    printf '%s' "$token" >"$directory/home/.local/state/herdr-sandbox/capability"
    chmod 600 "$directory/home/.local/state/herdr-sandbox/capability"
    printf '%s' "$credential_sync_digest" >"$directory/home/.local/state/herdr-sandbox/credential-sync-digest"
    "$HERDR_SANDBOX_TAR" -cf - -C "$directory/home" . |
        "$HERDR_SANDBOX_SSH" $ssh_options "$target" \
            'sudo -n systemd-run --quiet --wait --pipe --collect --machine=herdr-workspace --uid=agent /usr/bin/tar -xf - -C /home/agent'
    set -l result $status
    rm -rf "$directory"
    return $result
end

sync_runtime_home; or exit 1

# A fresh workspace may publish only before credentials, agent setup, or user attachment.
if test "$template_candidate" != true
    prepare_project; or exit 1
end

# The first compatible fresh workspace publishes a credential-free, stopped disk template.
set -l template_ready "$HERDR_SANDBOX_TEMPLATE_ROOT/$template_key/active/READY"
set -l template_fresh false
if test -f "$template_ready"; and test -n ("$HERDR_SANDBOX_FIND" "$template_ready" -mtime -7 -print -quit)
    set template_fresh true
end
if test "$template_candidate" = true; and test "$template_fresh" != true
    "$HERDR_SANDBOX_SSH" $ssh_options "$target" \
        'sudo -n herdr-guest-provision template-sanitize'; or exit 1
    "$HERDR_SANDBOX_SSH" $ssh_options -O exit "$target" >/dev/null 2>&1; or true
    "$HERDR_SANDBOX_SYSTEMCTL" start "herdr-microvm-template@$sandbox.service"; or exit 1
    "$HERDR_SANDBOX_SSH_KEYGEN" -f "$known_hosts" -R "$sandbox" >/dev/null 2>&1; or true
    rm -f "$runtime_state"
    "$HERDR_SANDBOX_SYSTEMCTL" restart "$unit"; or exit 1
    "$HERDR_SANDBOX_SYSTEMCTL" start "herdr-microvm-access@$sandbox.service"; or exit 1
    set ssh_ready false
    for _attempt in (seq 150)
        if "$HERDR_SANDBOX_SSH" $ssh_options "$target" true >/dev/null 2>&1
            set ssh_ready true
            break
        end
        sleep 0.1
    end
    test "$ssh_ready" = true; or begin
        echo "[herdr-sandbox] templated workspace did not restart" >&2
        exit 1
    end
    cat "$HERDR_SANDBOX_PROXY_CA_CERT" |
        "$HERDR_SANDBOX_SSH" $ssh_options "$target" 'sudo -n herdr-guest-provision proxy-ca'
    or exit 1
    "$HERDR_SANDBOX_JQ" -n \
        --arg checkoutPath "$checkout" --arg branch "$branch" --arg originUrl "$origin_url" \
        '{checkoutPath: $checkoutPath, branch: $branch, originUrl: $originUrl}' |
        "$HERDR_SANDBOX_SSH" $ssh_options "$target" 'sudo -n herdr-guest-provision metadata'
    or exit 1
    set -l reseed_bundle (mktemp "$state_directory/sync/$sandbox.bundle.XXXXXX")
    "$HERDR_SANDBOX_GIT" -C "$repo_root" bundle create "$reseed_bundle" --all; or exit 1
    "$HERDR_SANDBOX_SSH" $ssh_options "$target" 'sudo -n herdr-guest-provision seed' <"$reseed_bundle"
    set -l reseed_status $status
    rm -f "$reseed_bundle"
    test $reseed_status -eq 0; or exit 1
    "$HERDR_SANDBOX_SSH" $ssh_options "$target" 'sudo -n herdr-guest-provision start'; or exit 1
    "$HERDR_SANDBOX_SSH" $ssh_options "$target" 'sudo -n herdr-guest-provision ready'; or exit 1
    sync_runtime_home; or exit 1
    prepare_project; or exit 1
end

sync_credentials; or exit 1

# A read-only Git transport exposes guest commits as a normal host remote once per VM incarnation.
set -l remote_name "$sandbox"
set -l remote_url "herdr::$sandbox"
if "$HERDR_SANDBOX_GIT" -C "$repo_root" remote get-url "$remote_name" >/dev/null 2>&1
    "$HERDR_SANDBOX_GIT" -C "$repo_root" remote set-url "$remote_name" "$remote_url"
else
    "$HERDR_SANDBOX_GIT" -C "$repo_root" remote add "$remote_name" "$remote_url"
end
"$HERDR_SANDBOX_GIT" -C "$repo_root" fetch --quiet "$remote_name"; or exit 1

set invocation (unit_identity "$unit"); or exit 1
rm -f "$runtime_state"
set -l temporary_state "$runtime_state."(random)
"$HERDR_SANDBOX_JQ" -n \
    --arg invocation "$invocation" \
    --arg sync "$sync_digest" \
    --arg project "$project_fingerprint" \
    --arg devenv "$devenv_fingerprint" \
    --arg dependencies "$dependency_fingerprint" \
    --arg workspace "$HERDR_WORKSPACE_ID" \
    '{invocation: $invocation, sync: $sync, project: $project, devenv: $devenv, dependencies: $dependencies, workspace: $workspace}' \
    >"$temporary_state"
chmod 600 "$temporary_state"
mv -f "$temporary_state" "$runtime_state"
rm -rf "$slow_lock"
set -e __herdr_slow_lock
attach_pane attach
