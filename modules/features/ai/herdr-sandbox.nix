{
  den,
  inputs,
  ...
}: let
  local = import ../../_lib/local.nix;
  endpoints = import ./_herdr-sandbox/endpoints.nix;
  brokerPort = 18743;
  egressPort = 18744;
  proxyPort = 18745;
  credentialToken = "herdr-sandbox-credential";
  systemState = "/var/lib/herdr-sandbox";
in {
  flake-file.inputs.microvm = {
    url = "github:microvm-nix/microvm.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.herdr-sandbox = {
    nixos = {
      lib,
      pkgs,
      ...
    }: let
      guest = inputs.nixpkgs.lib.nixosSystem {
        system = pkgs.stdenv.hostPlatform.system;
        modules = [
          inputs.microvm.nixosModules.microvm
          (import ./_herdr-sandbox/guest.nix {
            authorizedKeys = local.user.ssh.authorizedKeys;
            inherit brokerPort credentialToken egressPort;
            userHome = local.mkHome pkgs.stdenv.hostPlatform.system;
          })
        ];
      };
      runner = guest.config.microvm.declaredRunner;
    in {
      imports = [
        (import ./_herdr-sandbox/host.nix {
          inherit brokerPort lib pkgs runner;
          egressPort = egressPort;
          user = local.user.name;
          userHome = local.mkHome pkgs.stdenv.hostPlatform.system;
        })
      ];
    };

    homeManager = {
      config,
      lib,
      pkgs,
      ...
    }: let
      jsonFormat = pkgs.formats.json {};
      sandboxPackage = import ./_herdr-sandbox/package.nix {inherit lib pkgs;};
      stateDirectory = "${config.xdg.stateHome}/herdr-sandbox";
      proxyTokenFile = "${stateDirectory}/proxy-token";
      proxyCaCertificate = "${stateDirectory}/proxy-ca.crt";
      proxyCaKey = "${stateDirectory}/proxy-ca.key";
      templateContext = builtins.hashString "sha256" "herdr-template-v1:${sandboxPackage}:${builtins.hashFile "sha256" ./_herdr-sandbox/guest.nix}:${inputs.microvm.rev or "dirty"}:${inputs.nixpkgs.rev or "dirty"}";
      cacheHelper = pkgs.writeShellScriptBin "herdr-sandbox-cache" ''
        set -euo pipefail
        export PATH=${lib.makeBinPath [pkgs.coreutils pkgs.findutils pkgs.git pkgs.jq pkgs.sqlite]}
        schema=herdr-microvm-cache-v3
        canonical=/home/agent/workspace
        command=''${1:-}
        shift || true
        root= repo_root= profile= output=
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --root) root=$2; shift 2 ;;
            --repo-root) repo_root=$2; shift 2 ;;
            --profile) profile=$2; shift 2 ;;
            --output) output=$2; shift 2 ;;
            *) echo "invalid cache argument: $1" >&2; exit 2 ;;
          esac
        done
        for directory in "$root" "$repo_root"; do
          [ -d "$directory" ] && [ ! -L "$directory" ] &&
            [ "$(realpath "$directory")" = "$directory" ] || exit 2
        done
        [ -n "$profile" ] && [ "$(realpath "$profile")" = "$profile" ] || exit 2

        repository=$(git -C "$repo_root" rev-parse --git-common-dir)
        repository=$(realpath "$repo_root/$repository")
        repository_id=$(printf '%s' "$repository" | sha256sum | cut -d ' ' -f 1)
        context=$(printf '%s\0%s\0%s\0%s\0%s\0%s' \
          "$schema" x86_64-linux herdr-workspace "$canonical" /home/agent "$profile:$repository_id" |
          sha256sum | cut -d ' ' -f 1)
        legacy_context=$(printf '%s\0%s\0%s\0%s\0%s' \
          herdr-sandbox-cache-v2 herdr-sandbox /home/agent/workspace /home/agent "$(realpath "$profile/bin/devenv")" |
          sha256sum | cut -d ' ' -f 1)

        fingerprint() {
          local candidate=$1 namespace=$2 candidate_context=$3
          local listing digest name relative absolute mode hash
          listing=$(mktemp)
          trap 'rm -f "$listing"' RETURN
          {
            git -C "$candidate" ls-files --cached --others --exclude-standard -z
            for explicit in .env; do [ -f "$candidate/$explicit" ] && printf '%s\0' "$explicit"; done
          } | sort -zu |
            while IFS= read -r -d $'\0' relative; do
              name=''${relative##*/}
              case "$namespace:$name" in
                dependencies:package.json|dependencies:.npmrc|dependencies:.yarnrc|dependencies:.yarnrc.yml|dependencies:aube-lock.yaml|dependencies:aube-workspace.yaml|dependencies:bun.lock|dependencies:bun.lockb|dependencies:bunfig.toml|dependencies:deno.json|dependencies:deno.jsonc|dependencies:deno.lock|dependencies:npm-shrinkwrap.json|dependencies:package-lock.json|dependencies:pnpm-lock.yaml|dependencies:pnpm-workspace.yaml|dependencies:yarn.lock) ;;
                devenv:devenv.lock|devenv:devenv.nix|devenv:devenv.yaml|devenv:flake.lock|devenv:flake.nix|devenv:*.nix|devenv:.env|devenv:.env.*) ;;
                *) continue ;;
              esac
              absolute="$candidate/$relative"
              [ -f "$absolute" ] && [ ! -L "$absolute" ] || continue
              [ "$(stat -c %s "$absolute")" -le 16777216 ] || exit 2
              hash=$(sha256sum "$absolute" | cut -d ' ' -f 1)
              mode=$(stat -c %A "$absolute")
              printf '%s\0%s\0%s\0' "$relative" "$mode" "$hash" >> "$listing"
            done
          digest=$(cat "$listing" | sha256sum | cut -d ' ' -f 1)
          printf '%s\0%s\0%s' "$namespace" "$candidate_context" "$digest" |
            sha256sum | cut -d ' ' -f 1
        }

        legacy_fingerprint() {
          local candidate=$1 namespace=$2 name relative absolute
          {
            printf '%s\0%s' "$namespace" "$legacy_context"
            git -C "$candidate" ls-files --cached --others --exclude-standard -z | sort -z |
              while IFS= read -r -d $'\0' relative; do
                name=''${relative##*/}
                case "$namespace:$name" in
                  dependencies:package.json|dependencies:.npmrc|dependencies:.yarnrc|dependencies:.yarnrc.yml|dependencies:aube-lock.yaml|dependencies:aube-workspace.yaml|dependencies:bun.lock|dependencies:bun.lockb|dependencies:bunfig.toml|dependencies:deno.json|dependencies:deno.jsonc|dependencies:deno.lock|dependencies:npm-shrinkwrap.json|dependencies:package-lock.json|dependencies:pnpm-lock.yaml|dependencies:pnpm-workspace.yaml|dependencies:yarn.lock) ;;
                  devenv:devenv.lock|devenv:devenv.nix|devenv:devenv.yaml|devenv:flake.lock|devenv:flake.nix|devenv:*.nix|devenv:.env.*) ;;
                  *) continue ;;
                esac
                absolute="$candidate/$relative"
                [ -f "$absolute" ] && [ ! -L "$absolute" ] || continue
                [ "$(stat -c %s "$absolute")" -le 16777216 ] || exit 2
                printf '\0%s\0' "$relative"
                cat "$absolute"
              done
          } | sha256sum | cut -d ' ' -f 1
        }

        calculate() {
          local candidate=$1 legacy=$2 dependencies devenv tree project
          if [ "$legacy" = true ]; then
            dependencies=$(legacy_fingerprint "$candidate" dependencies)
            devenv=$(legacy_fingerprint "$candidate" devenv)
          else
            dependencies=$(fingerprint "$candidate" dependencies "$context")
            devenv=$(fingerprint "$candidate" devenv "$context")
          fi
          tree=$(git -C "$candidate" rev-parse 'HEAD^{tree}')
          project=$(printf '%s\0%s\0%s\0%s' "$schema" "$dependencies" "$devenv" "$tree" |
            sha256sum | cut -d ' ' -f 1)
          jq -cn --arg dependencies "$dependencies" --arg devenv "$devenv" \
            --arg project "$project" --arg repository "$repository_id" \
            '{dependencies:$dependencies,devenv:$devenv,project:$project,repository:$repository}'
        }

        if [ -n "$(git -C "$root" status --porcelain --untracked-files=normal)" ]; then
          echo "cache reuse requires a clean worktree" >&2
          exit 3
        fi
        if [ -f "$root/.env" ] ||
           find "$root" -xdev -type f -name '.env.*' -not -path '*/.git/*' -print -quit | grep -q .; then
          echo "cache reuse is disabled for host-only environment inputs" >&2
          exit 3
        fi
        expected=$(calculate "$root" false)
        if [ "$command" = fingerprint ]; then
          printf '%s\n' "$expected"
          exit 0
        fi
        [ "$command" = snapshot ] && [ -n "$output" ] && [ ! -e "$output" ] || exit 2
        expected_dependencies=$(jq -r .dependencies <<<"$expected")
        expected_devenv=$(jq -r .devenv <<<"$expected")
        current_head=$(git -C "$root" rev-parse HEAD)
        legacy_expected=$(calculate "$root" true)
        legacy_dependencies=$(jq -r .dependencies <<<"$legacy_expected")
        legacy_devenv=$(jq -r .devenv <<<"$legacy_expected")
        source=
        while IFS= read -r candidate; do
          [ "$candidate" != "$root" ] && [ -d "$candidate" ] && [ ! -L "$candidate" ] || continue
          [ "$(git -C "$candidate" rev-parse HEAD 2>/dev/null)" = "$current_head" ] || continue
          [ -z "$(git -C "$candidate" status --porcelain --untracked-files=normal 2>/dev/null)" ] || continue
          candidate_values=$(calculate "$candidate" false 2>/dev/null) || continue
          candidate_dependencies=$(jq -r .dependencies <<<"$candidate_values")
          candidate_devenv=$(jq -r .devenv <<<"$candidate_values")
          v3=false v2=false
          [ "$(cat "$candidate/node_modules/.herdr-sandbox-dependencies-v3" 2>/dev/null)" = "$expected_dependencies" ] &&
            [ "$(cat "$candidate/.devenv/.herdr-sandbox-devenv-v3" 2>/dev/null)" = "$expected_devenv" ] && v3=true
          [ "$(cat "$candidate/node_modules/.herdr-sandbox-dependencies-v2" 2>/dev/null)" = "$legacy_dependencies" ] &&
            [ "$(cat "$candidate/.devenv/.herdr-sandbox-devenv-v2" 2>/dev/null)" = "$legacy_devenv" ] && v2=true
          if { [ "$v3" = true ] || [ "$v2" = true ]; } &&
             [ "$candidate_dependencies" = "$expected_dependencies" ] &&
             [ "$candidate_devenv" = "$expected_devenv" ]; then
            source=$candidate
            break
          fi
        done < <(git -C "$root" worktree list --porcelain | ${pkgs.gawk}/bin/awk '/^worktree / {sub(/^worktree /, ""); print}')
        if [ -z "$source" ]; then
          jq -cn --argjson expected "$expected" '$expected + {reused:false}'
          exit 3
        fi

        source_devenv="$source/.devenv"
        source_database="$source_devenv/nix-eval-cache.db"
        [ -d "$source_devenv" ] && [ ! -L "$source_devenv" ] &&
          [ "$(realpath "$source_devenv")" = "$source_devenv" ] || exit 2
        if [ -e "$source_database" ]; then
          [ -f "$source_database" ] && [ ! -L "$source_database" ] &&
            [ "$(realpath "$source_database")" = "$source_database" ] || exit 2
        fi
        mkdir -m 0700 "$output"
        cp -a --reflink=auto -- "$source_devenv" "$output/.devenv"
        rm -rf "$output/.devenv/processes" "$output/.devenv/run" "$output/.devenv/gc"
        rm -f "$output/.devenv"/*.sqlite-journal "$output/.devenv"/*.sqlite-shm \
          "$output/.devenv"/*.sqlite-wal "$output/.devenv"/.herdr-sandbox-devenv-v?
        if [ -f "$source_database" ]; then
          escaped_target=''${output//\'/\'\'}/.devenv/nix-eval-cache.db.snapshot
          sqlite3 "$source_database" ".backup '$escaped_target'" >/dev/null 2>&1 || {
            rm -rf "$output"; exit 2;
          }
          mv "$output/.devenv/nix-eval-cache.db.snapshot" "$output/.devenv/nix-eval-cache.db"
          [ "$(sqlite3 "$output/.devenv/nix-eval-cache.db" 'PRAGMA quick_check')" = ok ] || {
            rm -rf "$output"; exit 2;
          }
        fi
        while IFS= read -r -d $'\0' dependency; do
          relative=''${dependency#"$source/"}
          mkdir -p "$output/$(dirname "$relative")"
          cp -a --reflink=auto -- "$dependency" "$output/$relative"
        done < <(find "$source" -maxdepth 3 -name node_modules -type d -prune -print0)
        rm -f "$output/node_modules/.herdr-sandbox-dependencies-v?"

        entries=0 expanded=0
        while IFS= read -r -d $'\0' entry; do
          entries=$((entries + 1))
          [ "$entries" -le 2000000 ] || { rm -rf "$output"; exit 2; }
          relative=''${entry#"$output/"}
          if [ -L "$entry" ]; then
            link=$(readlink "$entry")
            if [[ "$link" = /* ]]; then
              normalized=$(realpath -m "$link")
              [[ "$normalized" =~ ^/nix/store/[a-z0-9]{32}-[^/]+(/.*)?$ ]] || { rm -rf "$output"; exit 2; }
            else
              normalized=$(realpath -m "$canonical/$(dirname "$relative")/$link")
              case "$normalized" in "$canonical"|"$canonical"/*) ;; *) rm -rf "$output"; exit 2 ;; esac
            fi
          elif [ -f "$entry" ]; then
            size=$(stat -c %s "$entry")
            [ "$size" -le 1073741824 ] || { rm -rf "$output"; exit 2; }
            [ "$size" -eq 0 ] || [ "$(( $(stat -c %b "$entry") * 512 ))" -ge "$size" ] || { rm -rf "$output"; exit 2; }
            expanded=$((expanded + size))
            [ "$expanded" -le 8589934592 ] || { rm -rf "$output"; exit 2; }
            chmod u-s,g-s,o-t "$entry"
            if [ "$(stat -c %h "$entry")" -gt 1 ]; then
              replacement="$entry.herdr-copy-$$"
              cp --reflink=auto -- "$entry" "$replacement"
              chmod --reference="$entry" "$replacement"
              mv -f "$replacement" "$entry"
            fi
          elif [ -d "$entry" ]; then
            chmod u-s,g-s,o-t "$entry"
          else
            rm -rf "$output"
            exit 2
          fi
        done < <(find "$output" -xdev -mindepth 1 -print0)
        after=$(calculate "$source" false)
        [ "$(jq -r .dependencies <<<"$after")" = "$expected_dependencies" ] &&
          [ "$(jq -r .devenv <<<"$after")" = "$expected_devenv" ] || { rm -rf "$output"; exit 2; }
        jq -n --arg schema "$schema" --argjson expected "$expected" \
          --arg sourceHead "$current_head" --argjson entries "$entries" \
          --argjson expandedBytes "$expanded" \
          '$expected + {schema:$schema,sourceHead:$sourceHead,entries:$entries,expandedBytes:$expandedBytes}' \
          >"$output/.herdr-cache-manifest.json"
        chmod 0600 "$output/.herdr-cache-manifest.json"
        jq -cn --argjson expected "$expected" --arg source "$source" \
          --argjson entries "$entries" --argjson expandedBytes "$expanded" \
          '$expected + {reused:true,source:$source,entries:$entries,expandedBytes:$expandedBytes}'
      '';
      sshProxy = "${pkgs.systemd}/lib/systemd/systemd-ssh-proxy";
      sshKey = "${config.home.homeDirectory}/.ssh/id_ed25519";
      brokerConfig = jsonFormat.generate "herdr-sandbox.json" {
        herdrSocketPath = "${config.xdg.configHome}/herdr/herdr.sock";
        inherit stateDirectory proxyTokenFile credentialToken;
        listenPort = brokerPort;
        inherit egressPort proxyPort;
        credentialPaths = [
          "/github_api"
          "/github_web"
          "/supermemory"
        ];
        allowedEndpoints = endpoints;
      };
      githubBasicCredential = pkgs.writeShellScript "herdr-github-basic-credential" ''
        set -euo pipefail
        token="$(${lib.getExe pkgs.gh} auth token)"
        printf 'x-access-token:%s' "$token" | ${pkgs.coreutils}/bin/base64 -w0
      '';
      proxyProfile = jsonFormat.generate "herdr-sandbox-nono.json" {
        meta.name = "herdr-sandbox";
        network = {
          credentials = [
            "github_api"
            "github_web"
            "supermemory"
          ];
          custom_credentials = {
            github_api = {
              upstream = "https://api.github.com";
              credential_key = "cmd://github_api";
              env_var = "GH_TOKEN";
              inject_header = "Authorization";
              credential_format = "Bearer {}";
            };
            github_web = {
              upstream = "https://github.com";
              credential_key = "cmd://github_web";
              env_var = "GH_TOKEN";
              inject_header = "Authorization";
              credential_format = "Basic {}";
            };
            supermemory = {
              upstream = "https://api.supermemory.ai";
              credential_key = "file://${local.secretPath "supermemory-api-key"}";
              env_var = "SUPERMEMORY_API_KEY";
              inject_header = "Authorization";
              credential_format = "Bearer {}";
            };
          };
        };
        credential_capture = {
          github_api = {
            command = [
              (lib.getExe pkgs.gh)
              "auth"
              "token"
            ];
            timeout_secs = 5;
            cache_ttl_secs = 900;
          };
          github_web = {
            command = [githubBasicCredential];
            timeout_secs = 5;
            cache_ttl_secs = 900;
          };
        };
      };
      allowedDomains = lib.unique (map (endpoint: endpoint.host) endpoints);
      proxyArguments =
        [
          "proxy"
          "--silent"
          "--profile"
          proxyProfile
          "--listen"
          "127.0.0.1"
          "--port"
          (toString proxyPort)
          "--max-connections"
          "1024"
        ]
        ++ lib.concatMap (host: ["--allow-domain" host]) allowedDomains;
      ensureProxyState = pkgs.writeShellScript "herdr-sandbox-proxy-state" ''
        set -euo pipefail
        token_file=${lib.escapeShellArg proxyTokenFile}
        ca_cert=${lib.escapeShellArg proxyCaCertificate}
        ca_key=${lib.escapeShellArg proxyCaKey}
        ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg stateDirectory}

        if ! [ -f "$token_file" ] ||
           ! ${pkgs.gnugrep}/bin/grep -Eq '^[a-f0-9]{64}$' "$token_file"; then
          umask 0077
          temporary="$token_file.$$"
          ${lib.getExe pkgs.openssl} rand -hex 32 > "$temporary"
          ${pkgs.coreutils}/bin/mv -f "$temporary" "$token_file"
        fi

        if ! [ -r "$ca_cert" ] || ! [ -r "$ca_key" ] ||
           ! ${lib.getExe pkgs.openssl} x509 -in "$ca_cert" -noout -checkend 86400 >/dev/null 2>&1 ||
           ! ${lib.getExe pkgs.openssl} pkey -in "$ca_key" -noout >/dev/null 2>&1; then
          umask 0077
          temporary_key="$ca_key.$$"
          temporary_cert="$ca_cert.$$"
          ${lib.getExe pkgs.openssl} genpkey -algorithm EC \
            -pkeyopt ec_paramgen_curve:P-256 -out "$temporary_key"
          ${lib.getExe pkgs.openssl} req -x509 -new -key "$temporary_key" \
            -sha256 -days 3650 -subj "/CN=Herdr Sandbox Proxy CA" \
            -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
            -addext "keyUsage=critical,keyCertSign,cRLSign" \
            -out "$temporary_cert"
          ${pkgs.coreutils}/bin/chmod 0600 "$temporary_key" "$temporary_cert"
          ${pkgs.coreutils}/bin/mv -f "$temporary_key" "$ca_key"
          ${pkgs.coreutils}/bin/mv -f "$temporary_cert" "$ca_cert"
        fi
      '';
      runProxy = pkgs.writeShellScript "herdr-sandbox-proxy" ''
        set -euo pipefail
        ${ensureProxyState}
        export NONO_PROXY_PASS="$(cat ${lib.escapeShellArg proxyTokenFile})"
        export NONO_PROXY_CA_CERT=${lib.escapeShellArg proxyCaCertificate}
        export NONO_PROXY_CA_KEY=${lib.escapeShellArg proxyCaKey}
        exec ${lib.getExe pkgs.nono} ${lib.escapeShellArgs proxyArguments}
      '';
      gitTransport = pkgs.writeShellScriptBin "herdr-git-transport" ''
        set -euo pipefail
        id=''${1:-}
        service=''${2:-}
        repository=''${3:-}
        if ! [[ "$id" =~ ^herdr-[0-9a-f]{20}$ ]] ||
           [ "$service" != git-upload-pack ] ||
           [ "$repository" != /var/lib/herdr/checkout ]; then
          echo "invalid Herdr Git transport request" >&2
          exit 2
        fi
        state="''${XDG_STATE_HOME:-$HOME/.local/state}/herdr-sandbox"
        target="agent@vsock-mux${systemState}/workspaces/$id/run/notify.vsock"
        exec ${pkgs.openssh}/bin/ssh \
          -F /dev/null \
          -o ${lib.escapeShellArg "ProxyCommand ${sshProxy} %h %p"} \
          -o ProxyUseFdpass=yes \
          -o ${lib.escapeShellArg "IdentityFile=${sshKey}"} \
          -o IdentitiesOnly=yes \
          -o "UserKnownHostsFile=$state/known-hosts" \
          -o "HostKeyAlias=$id" \
          -o StrictHostKeyChecking=yes \
          -o LogLevel=ERROR \
          "$target" \
          "$service '$repository'"
      '';
      gitRemoteHelper = pkgs.writeShellScriptBin "git-remote-herdr" ''
        set -euo pipefail
        remote=''${1:-}
        id=''${2:-}
        if ! [[ "$id" =~ ^herdr-[0-9a-f]{20}$ ]]; then
          echo "invalid Herdr Git remote: $id" >&2
          exit 2
        fi
        command="${gitTransport}/bin/herdr-git-transport $id %S /var/lib/herdr/checkout"
        exec ${pkgs.git}/bin/git remote-ext "$remote" "$command"
      '';
      sandboxControl = pkgs.writeShellScriptBin "herdr-sandboxctl" ''
        set -euo pipefail
        action=''${1:-list}
        id=''${2:-}
        state=${lib.escapeShellArg stateDirectory}

        validate_id() {
          if ! [[ "$1" =~ ^herdr-[0-9a-f]{20}$ ]]; then
            echo "invalid Herdr sandbox name: $1" >&2
            exit 2
          fi
        }

        close_master() {
          local sandbox=$1
          local runtime="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/herdr-sandbox"
          local target="agent@vsock-mux${systemState}/workspaces/$sandbox/run/notify.vsock"
          ${pkgs.openssh}/bin/ssh \
            -F /dev/null \
            -o ${lib.escapeShellArg "ProxyCommand ${sshProxy} %h %p"} \
            -o ProxyUseFdpass=yes \
            -o ${lib.escapeShellArg "IdentityFile=${sshKey}"} \
            -o IdentitiesOnly=yes \
            -o "UserKnownHostsFile=$state/known-hosts" \
            -o "HostKeyAlias=$sandbox" \
            -o "ControlPath=$runtime/masters/$sandbox" \
            -O exit "$target" >/dev/null 2>&1 || true
        }

        case "$action" in
          list)
            exec ${pkgs.systemd}/bin/systemctl list-units \
              'herdr-microvm@*.service' --all --no-pager
            ;;
          status|start)
            validate_id "$id"
            exec ${pkgs.systemd}/bin/systemctl "$action" \
              "herdr-microvm@$id.service"
            ;;
          stop|restart)
            validate_id "$id"
            close_master "$id"
            exec ${pkgs.systemd}/bin/systemctl "$action" \
              "herdr-microvm@$id.service"
            ;;
          remove)
            validate_id "$id"
            close_master "$id"
            force=''${3:-}
            if [ -n "$force" ] && [ "$force" != "--force" ]; then
              echo "usage: herdr-sandboxctl remove herdr-ID [--force]" >&2
              exit 2
            fi
            registration="$state/registrations/$id.json"
            checkout=""
            if [ -f "$registration" ]; then
              checkout=$(${lib.getExe pkgs.jq} -r '.checkoutPath // empty' "$registration")
            fi
            if [ -z "$checkout" ] || ! ${lib.getExe pkgs.git} -C "$checkout" rev-parse --git-dir >/dev/null 2>&1; then
              if [ "$force" != "--force" ]; then
                echo "cannot prove publication safety without the workspace registration; use --force to discard it" >&2
                exit 1
              fi
            else
              target="agent@vsock-mux${systemState}/workspaces/$id/run/notify.vsock"
              ssh_guest=(
                ${pkgs.openssh}/bin/ssh
                -F /dev/null
                -o ${lib.escapeShellArg "ProxyCommand ${sshProxy} %h %p"}
                -o ProxyUseFdpass=yes
                -o ${lib.escapeShellArg "IdentityFile=${sshKey}"}
                -o IdentitiesOnly=yes
                -o "UserKnownHostsFile=$state/known-hosts"
                -o "HostKeyAlias=$id"
                -o StrictHostKeyChecking=yes
                -o LogLevel=ERROR
                "$target"
              )
              if ${pkgs.systemd}/bin/systemctl start "herdr-microvm@$id.service" &&
                 "''${ssh_guest[@]}" sudo /run/current-system/sw/bin/systemctl \
                   stop herdr-workspace-container.service &&
                 ${lib.getExe pkgs.git} -C "$checkout" fetch --quiet "$id" \
                   "+HEAD:refs/herdr/archive/$id/HEAD" \
                   "+refs/heads/*:refs/herdr/archive/$id/heads/*" \
                   "+refs/tags/*:refs/herdr/archive/$id/tags/*"; then
                dirty=""
                if ! dirty=$("''${ssh_guest[@]}" \
                  'git -C /var/lib/herdr/checkout status --porcelain'); then
                  if [ "$force" != "--force" ]; then
                    echo "failed to inspect guest worktree; use --force to discard the workspace" >&2
                    exit 1
                  fi
                fi
                if [ -n "$dirty" ] && [ "$force" != "--force" ]; then
                  echo "workspace has uncommitted changes; commit them or use --force" >&2
                  exit 1
                fi
              elif [ "$force" != "--force" ]; then
                echo "failed to publish guest refs; use --force to discard the workspace" >&2
                exit 1
              fi
              ${lib.getExe pkgs.git} -C "$checkout" remote remove "$id" 2>/dev/null || true
            fi
            ${pkgs.systemd}/bin/systemctl start "herdr-microvm-remove@$id.service"
            ${pkgs.openssh}/bin/ssh-keygen -f "$state/known-hosts" -R "$id" >/dev/null 2>&1 || true
            rm -f "$registration" "$state/capabilities/$id"
            ;;
          *)
            echo "usage: herdr-sandboxctl list|status|start|stop|restart|remove [herdr-ID] [--force]" >&2
            exit 2
            ;;
        esac
      '';
      sandboxShell = pkgs.writeShellScript "herdr-sandbox-shell" ''
        export HERDR_SANDBOX_HERDR="$(command -v herdr)"
        export HERDR_SANDBOX_JQ=${lib.getExe pkgs.jq}
        export HERDR_SANDBOX_BASE64=${pkgs.coreutils}/bin/base64
        export HERDR_SANDBOX_CACHE=${cacheHelper}/bin/herdr-sandbox-cache
        export HERDR_SANDBOX_FIND=${pkgs.findutils}/bin/find
        export HERDR_SANDBOX_SHA256SUM=${pkgs.coreutils}/bin/sha256sum
        export HERDR_SANDBOX_OPENSSL=${lib.getExe pkgs.openssl}
        export HERDR_SANDBOX_TAR=${pkgs.gnutar}/bin/tar
        export HERDR_SANDBOX_GIT=${lib.getExe pkgs.git}
        export HERDR_SANDBOX_NIX=${lib.getExe pkgs.nix}
        export HERDR_SANDBOX_SSH=${pkgs.openssh}/bin/ssh
        export HERDR_SANDBOX_SSH_KEYGEN=${pkgs.openssh}/bin/ssh-keygen
        export HERDR_SANDBOX_PANE_SSH=${sandboxPackage}/libexec/fish
        export HERDR_SANDBOX_SSH_PROXY=${lib.escapeShellArg sshProxy}
        export HERDR_SANDBOX_SSH_KEY=${lib.escapeShellArg sshKey}
        export HERDR_SANDBOX_SYSTEMCTL=${pkgs.systemd}/bin/systemctl
        export HERDR_SANDBOX_GUEST_HOME=${sandboxPackage}/share/herdr-sandbox/home
        export HERDR_SANDBOX_HOST_SHELL=${lib.getExe pkgs.fish}
        export HERDR_SANDBOX_HOST_HOME=${lib.escapeShellArg config.home.homeDirectory}
        export HERDR_SANDBOX_HOST_NAME="$(${lib.getExe pkgs.hostname})"
        export HERDR_SANDBOX_HOST_PROFILE="$(${pkgs.coreutils}/bin/readlink -f ${lib.escapeShellArg "${config.home.homeDirectory}/.nix-profile"})"
        export HERDR_SANDBOX_HOME_FILES="$(${pkgs.coreutils}/bin/readlink -f ${lib.escapeShellArg "${config.xdg.stateHome}/home-manager/gcroots/current-home/home-files"})"
        export HERDR_SANDBOX_STATE_DIRECTORY=${lib.escapeShellArg stateDirectory}
        export HERDR_SANDBOX_RUNTIME_DIRECTORY="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/herdr-sandbox"
        export HERDR_SANDBOX_PROXY_CA_CERT=${lib.escapeShellArg proxyCaCertificate}
        export HERDR_SANDBOX_SYSTEM_STATE=${lib.escapeShellArg systemState}
        export HERDR_SANDBOX_TEMPLATE_ROOT=${lib.escapeShellArg "${systemState}/templates/v1"}
        export HERDR_SANDBOX_TEMPLATE_CONTEXT=${lib.escapeShellArg templateContext}
        export HERDR_SANDBOX_BROKER_PORT=${toString brokerPort}
        export HERDR_SANDBOX_EGRESS_PORT=${toString egressPort}
        export HERDR_SANDBOX_CREDENTIAL_TOKEN=${lib.escapeShellArg credentialToken}
        export HERDR_SANDBOX_ZSTD=${lib.getExe pkgs.zstd}
        exec ${lib.getExe pkgs.fish} ${./_herdr-sandbox/shell.fish}
      '';
    in {
      herdrSandbox.shell = "${sandboxShell}";

      home.packages = [
        gitRemoteHelper
        gitTransport
        pkgs.nix
        pkgs.nono
        sandboxControl
        sandboxPackage
      ];

      systemd.user.services = {
        herdr-sandbox-proxy-token = {
          Unit = {
            Description = "Generate the Herdr egress proxy state";
            Before = [
              "herdr-sandbox-proxy.service"
              "herdr-sandbox.service"
            ];
            X-SwitchMethod = "restart";
          };
          Service = {
            Type = "oneshot";
            ExecStart = ensureProxyState;
            RemainAfterExit = true;
          };
          Install.WantedBy = ["default.target"];
        };

        herdr-sandbox-proxy = {
          Unit = {
            Description = "Fail-closed egress proxy for Herdr MicroVMs";
            After = ["herdr-sandbox-proxy-token.service"];
            Requires = ["herdr-sandbox-proxy-token.service"];
            X-SwitchMethod = "restart";
          };
          Service = {
            ExecStart = runProxy;
            Restart = "on-failure";
            RestartSec = 2;
            NoNewPrivileges = true;
            PrivateTmp = true;
          };
          Install.WantedBy = ["default.target"];
        };

        herdr-sandbox = {
          Unit = {
            Description = "Scoped Herdr broker for sandboxed Pi sessions";
            After = [
              "herdr-sandbox-proxy-token.service"
              "herdr-sandbox-proxy.service"
            ];
            Requires = ["herdr-sandbox-proxy-token.service"];
            Wants = ["herdr-sandbox-proxy.service"];
            X-SwitchMethod = "restart";
          };
          Service = {
            ExecStart = "${sandboxPackage}/bin/herdr-sandboxd --config ${brokerConfig}";
            Restart = "on-failure";
            RestartSec = 2;
            NoNewPrivileges = true;
            PrivateTmp = true;
          };
          Install.WantedBy = ["default.target"];
        };
      };
    };
  };
}
