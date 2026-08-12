{
  brokerPort,
  egressPort,
  lib,
  pkgs,
  runner,
  user,
  userHome,
}: let
  stateRoot = "/var/lib/herdr-sandbox";
  templateRoot = "${stateRoot}/templates/v1";
  requestRoot = "${userHome}/.local/state/herdr-sandbox/requests";
  instancePattern = "herdr-[0-9a-f]{20}";
  validateInstance = ''
    case "$1" in
      herdr-????????????????????) ;;
      *) echo "invalid Herdr sandbox name: $1" >&2; exit 2 ;;
    esac
    if ! printf '%s' "$1" | ${pkgs.gnugrep}/bin/grep -Eq '^${instancePattern}$'; then
      echo "invalid Herdr sandbox name: $1" >&2
      exit 2
    fi
  '';
  readTemplateRequest = ''
    request=${requestRoot}/$name.json
    if [ "$(${pkgs.coreutils}/bin/stat -c %F -- "$request" 2>/dev/null)" != "regular file" ] ||
       [ "$(${pkgs.coreutils}/bin/stat -c %U -- "$request" 2>/dev/null)" != ${lib.escapeShellArg user} ] ||
       [ "$(${pkgs.coreutils}/bin/stat -c %a -- "$request" 2>/dev/null)" != 600 ] ||
       [ "$(${pkgs.coreutils}/bin/readlink -f -- "$request")" != "$request" ]; then
      echo "invalid Herdr template request" >&2
      exit 2
    fi
    requested_template_key=$(${lib.getExe pkgs.jq} -er '.templateKey' "$request")
    template_eligible=$(${lib.getExe pkgs.jq} -er '.templateEligible' "$request")
    if ! printf '%s' "$requested_template_key" | ${pkgs.gnugrep}/bin/grep -Eq '^[a-f0-9]{64}$' ||
       { [ "$template_eligible" != true ] && [ "$template_eligible" != false ]; }; then
      echo "invalid Herdr template key" >&2
      exit 2
    fi
    template_key=$(printf '%s\0%s' "$requested_template_key" ${lib.escapeShellArg (toString runner)} |
      ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)
  '';
  prepare = pkgs.writeShellScript "herdr-microvm-prepare" ''
    set -euo pipefail
    ${validateInstance}
    name=$1
    directory=${stateRoot}/workspaces/$name
    ${readTemplateRequest}

    ${pkgs.coreutils}/bin/install -d -o root -g kvm -m 0750 "$directory"
    ${pkgs.coreutils}/bin/install -d -o microvm -g kvm -m 0700 "$directory/images"
    ${pkgs.coreutils}/bin/install -d -o microvm -g kvm -m 0770 "$directory/run"
    ${pkgs.coreutils}/bin/install -d -o root -g kvm -m 0750 "$directory/shares"
    if [ -e "$directory/template-clone-pending" ]; then
      if [ ! -e "$directory/attached" ] && [ -e "$directory/template-candidate" ]; then
        ${pkgs.coreutils}/bin/rm -f \
          "$directory/images/root.img" "$directory/images/docker.img" \
          "$directory/images/root.img.new" "$directory/images/docker.img.new" \
          "$directory/template.json" "$directory/template.json.new" \
          "$directory/template-clone-pending"
      else
        echo "incomplete Herdr template clone" >&2
        exit 1
      fi
    fi
    if { [ -e "$directory/images/root.img" ] && [ ! -e "$directory/images/docker.img" ]; } ||
       { [ ! -e "$directory/images/root.img" ] && [ -e "$directory/images/docker.img" ]; }; then
      echo "partial Herdr workspace image set" >&2
      exit 1
    fi
    if [ ! -e "$directory/images/root.img" ] && [ ! -e "$directory/images/docker.img" ]; then
      ${pkgs.coreutils}/bin/install -o root -g kvm -m 0440 /dev/null "$directory/template-candidate"
    else
      ${pkgs.coreutils}/bin/rm -f "$directory/template-candidate"
    fi

    if [ "$template_eligible" = true ] &&
       [ ! -e "$directory/images/root.img" ] &&
       [ ! -e "$directory/images/docker.img" ]; then
      exec 8>${stateRoot}/template.lock
      ${lib.getExe' pkgs.util-linux "flock"} --shared 8
      active=${templateRoot}/$template_key/active
      if [ -L "$active" ]; then
        generation=$(${pkgs.coreutils}/bin/readlink -f -- "$active")
        case "$generation" in
          ${templateRoot}/$template_key/generations/*) ;;
          *) echo "invalid Herdr template generation" >&2; exit 2 ;;
        esac
        if [ ! -f "$generation/READY" ] ||
           ! ${pkgs.findutils}/bin/find "$generation/READY" -mtime -7 -print -quit | ${pkgs.gnugrep}/bin/grep -q .; then
          generation=""
        fi
        if [ -z "$generation" ]; then
          rm -f "$active"
        else
        required=5368709120
        for image in root docker; do
          required=$((required + $(${pkgs.coreutils}/bin/du -B1 "$generation/$image.base.raw" | ${pkgs.coreutils}/bin/cut -f 1)))
        done
        available=$(${pkgs.coreutils}/bin/df --output=avail -B1 "$directory" | ${pkgs.coreutils}/bin/tail -1)
        if [ "$available" -lt "$required" ]; then
          echo "insufficient space for a Herdr workspace template" >&2
          exit 1
        fi
        ${pkgs.coreutils}/bin/install -o root -g kvm -m 0440 /dev/null "$directory/template-clone-pending"
        manifest_runner=$(${lib.getExe pkgs.jq} -er '.runner' "$generation/manifest.json")
        if [ "$manifest_runner" != ${lib.escapeShellArg (toString runner)} ]; then
          echo "Herdr template runner does not match the active guest" >&2
          exit 1
        fi
        staged=()
        cleanup_clone() { for target in "''${staged[@]}"; do rm -f -- "$target"; done; }
        trap cleanup_clone EXIT
        for image in root docker; do
          source="$generation/$image.base.raw"
          target="$directory/images/$image.img"
          expected_label="herdr-$image"
          if [ "$(${pkgs.coreutils}/bin/stat -c '%U:%G:%a:%s' -- "$source")" != "root:kvm:440:21474836480" ] ||
             [ "$(${lib.getExe' pkgs.util-linux "blkid"} -s LABEL -o value "$source")" != "$expected_label" ]; then
            echo "invalid Herdr template image: $image" >&2
            exit 1
          fi
          temporary="$target.new"
          ${pkgs.coreutils}/bin/cp --reflink=auto --sparse=always -- "$source" "$temporary"
          ${pkgs.coreutils}/bin/chown microvm:kvm "$temporary"
          ${pkgs.coreutils}/bin/chmod 0600 "$temporary"
          staged+=("$temporary")
        done
        ${pkgs.coreutils}/bin/install -o root -g kvm -m 0440 \
          "$generation/manifest.json" "$directory/template.json.new"
        staged+=("$directory/template.json.new")
        ${pkgs.coreutils}/bin/mv "$directory/images/root.img.new" "$directory/images/root.img"
        ${pkgs.coreutils}/bin/mv "$directory/images/docker.img.new" "$directory/images/docker.img"
        ${pkgs.coreutils}/bin/mv "$directory/template.json.new" "$directory/template.json"
        staged=()
        trap - EXIT
        ${pkgs.coreutils}/bin/rm -f "$directory/template-candidate" "$directory/template-clone-pending"
        fi
      fi
    fi

    mount_share() {
      local name=$1 source=$2 target="$directory/shares/$1"
      if ${lib.getExe' pkgs.util-linux "mountpoint"} --quiet "$target"; then
        ${lib.getExe' pkgs.util-linux "umount"} "$target"
      fi
      ${pkgs.coreutils}/bin/rm -rf "$target"
      ${pkgs.coreutils}/bin/install -d -o root -g kvm -m 0550 "$target"
      if [ -d "$source" ]; then
        ${lib.getExe' pkgs.util-linux "mount"} --bind "$source" "$target"
        ${lib.getExe' pkgs.util-linux "mount"} \
          -o remount,bind,ro "$target"
      fi
    }

    mount_share npm ${lib.escapeShellArg "${userHome}/.pi/agent/npm"}
    mount_share git ${lib.escapeShellArg "${userHome}/.pi/agent/git"}
    mount_share nix ${lib.escapeShellArg "${userHome}/.cache/nix"}
    mount_share playwright ${lib.escapeShellArg "${userHome}/.cache/ms-playwright"}

    ${pkgs.coreutils}/bin/install -d -o root -g root -m 0755 \
      /nix/var/nix/gcroots/herdr-sandbox
    ${pkgs.coreutils}/bin/ln -sfn ${runner} \
      "/nix/var/nix/gcroots/herdr-sandbox/$name"
  '';
  unmountShares = pkgs.writeShellScript "herdr-microvm-unmount-shares" ''
    set -euo pipefail
    ${validateInstance}
    directory=${stateRoot}/workspaces/$1/shares
    for name in npm git nix playwright; do
      target="$directory/$name"
      if ${lib.getExe' pkgs.util-linux "mountpoint"} --quiet "$target"; then
        ${lib.getExe' pkgs.util-linux "umount"} "$target"
      fi
    done
  '';
  pinRunner = pkgs.writeShellScript "herdr-microvm-pin-runner" ''
    set -euo pipefail
    ${validateInstance}
    ${pkgs.coreutils}/bin/install -d -o root -g root -m 0755 \
      /nix/var/nix/gcroots/herdr-sandbox
    ${pkgs.coreutils}/bin/ln -sfn ${runner} \
      "/nix/var/nix/gcroots/herdr-sandbox/$1"
  '';
  publishVsock = pkgs.writeShellScript "herdr-microvm-publish-vsock" ''
    set -euo pipefail
    ${validateInstance}
    socket=${stateRoot}/workspaces/$1/run/notify.vsock
    test -S "$socket"
    ${pkgs.coreutils}/bin/chgrp kvm "$socket"
    ${pkgs.coreutils}/bin/chmod 0660 "$socket"
  '';
  markAttached = pkgs.writeShellScript "herdr-microvm-mark-attached" ''
    set -euo pipefail
    ${validateInstance}
    directory=${stateRoot}/workspaces/$1
    ${pkgs.coreutils}/bin/install -o root -g kvm -m 0440 /dev/null "$directory/attached"
    ${pkgs.coreutils}/bin/rm -f "$directory/template-candidate"
  '';
  relay = pkgs.writeShellScript "herdr-microvm-relay" ''
    set -euo pipefail
    ${validateInstance}
    name=$1
    directory=${stateRoot}/workspaces/$name/run
    broker_socket="$directory/notify.vsock_${toString brokerPort}"
    egress_socket="$directory/notify.vsock_${toString egressPort}"

    rm -f "$broker_socket" "$egress_socket"
    cleanup() {
      trap - EXIT INT TERM
      kill "$broker_pid" "$egress_pid" 2>/dev/null || true
      wait "$broker_pid" "$egress_pid" 2>/dev/null || true
      rm -f "$broker_socket" "$egress_socket"
    }
    terminate() {
      cleanup
      exit 0
    }
    trap cleanup EXIT
    trap terminate INT TERM

    ${pkgs.socat}/bin/socat \
      "UNIX-LISTEN:$broker_socket,fork,mode=0600" \
      "TCP:127.0.0.1:${toString brokerPort}" &
    broker_pid=$!
    ${pkgs.socat}/bin/socat \
      "UNIX-LISTEN:$egress_socket,fork,mode=0600" \
      "TCP:127.0.0.1:${toString egressPort}" &
    egress_pid=$!

    wait -n "$broker_pid" "$egress_pid"
  '';
  publishTemplate = pkgs.writeShellScript "herdr-microvm-publish-template" ''
    set -euo pipefail
    ${validateInstance}
    name=$1
    directory=${stateRoot}/workspaces/$name
    ${readTemplateRequest}
    if [ "$template_eligible" != true ]; then
      echo "workspace is not eligible to publish a template" >&2
      exit 1
    fi
    if [ -e "$directory/attached" ] ||
       [ ! -f "$directory/template-candidate" ] ||
       [ "$(${pkgs.coreutils}/bin/stat -c '%U:%G:%a' "$directory/template-candidate")" != "root:kvm:440" ]; then
      echo "only a never-attached workspace may publish a template" >&2
      exit 1
    fi
    key_directory=${templateRoot}/$template_key
    active="$key_directory/active"
    ${pkgs.coreutils}/bin/install -d -o root -g kvm -m 0750 ${templateRoot}
    exec 9>${stateRoot}/template.lock
    ${lib.getExe' pkgs.util-linux "flock"} 9
    ${pkgs.findutils}/bin/find ${templateRoot} -path '*/staging/*' -type d -mmin +60 -print0 |
      ${pkgs.findutils}/bin/xargs -0 -r ${pkgs.coreutils}/bin/rm -rf --
    ${pkgs.findutils}/bin/find ${templateRoot} \
      -mindepth 1 -maxdepth 1 -type d -mtime +30 -print0 |
      ${pkgs.findutils}/bin/xargs -0 -r ${pkgs.coreutils}/bin/rm -rf --
    allocated=$(${pkgs.coreutils}/bin/du -sb ${templateRoot} | ${pkgs.coreutils}/bin/cut -f 1)
    if [ "$allocated" -gt 107374182400 ]; then
      ${pkgs.findutils}/bin/find ${templateRoot} \
        -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' |
        ${pkgs.coreutils}/bin/sort -n |
        while read -r _ key; do
          [ "$key" = "$key_directory" ] && continue
          ${pkgs.coreutils}/bin/rm -rf -- "$key"
          allocated=$(${pkgs.coreutils}/bin/du -sb ${templateRoot} | ${pkgs.coreutils}/bin/cut -f 1)
          [ "$allocated" -le 107374182400 ] && break
        done
    fi
    ${pkgs.coreutils}/bin/install -d -o root -g kvm -m 0750 \
      "$key_directory" "$key_directory/generations" "$key_directory/staging"
    if [ -L "$active" ] && [ -f "$active/READY" ] &&
       ${pkgs.findutils}/bin/find "$active/READY" -mtime -7 -print -quit | ${pkgs.gnugrep}/bin/grep -q .; then
      ${pkgs.coreutils}/bin/rm -f "$directory/template-candidate"
      exit 0
    fi
    ${pkgs.systemd}/bin/systemctl stop "herdr-microvm@$name.service"
    if ${pkgs.systemd}/bin/systemctl is-active --quiet "herdr-microvm@$name.service"; then
      echo "refusing to snapshot a running Herdr MicroVM" >&2
      exit 1
    fi
    sanitized=$(${pkgs.e2fsprogs}/bin/debugfs -R 'stat /var/lib/herdr-template-sanitized' \
      "$directory/images/root.img" 2>/dev/null || true)
    if ! printf '%s' "$sanitized" | ${pkgs.gnugrep}/bin/grep -q '^Inode:'; then
      echo "workspace template was not sanitized by the guest" >&2
      exit 1
    fi
    for image in root docker; do
      source="$directory/images/$image.img"
      if [ "$(${pkgs.coreutils}/bin/stat -c '%U:%G:%a:%s' -- "$source")" != "microvm:kvm:600:21474836480" ] ||
         [ "$(${lib.getExe' pkgs.util-linux "blkid"} -s LABEL -o value "$source")" != "herdr-$image" ]; then
        echo "invalid stopped workspace image: $image" >&2
        exit 1
      fi
    done
    required=5368709120
    for image in root docker; do
      required=$((required + $(${pkgs.coreutils}/bin/du -B1 "$directory/images/$image.img" | ${pkgs.coreutils}/bin/cut -f 1)))
    done
    available=$(${pkgs.coreutils}/bin/df --output=avail -B1 "$key_directory" | ${pkgs.coreutils}/bin/tail -1)
    if [ "$available" -lt "$required" ]; then
      echo "insufficient space to publish a Herdr template" >&2
      exit 1
    fi
    generation="$(${lib.getExe pkgs.openssl} rand -hex 16)"
    staging="$key_directory/staging/$generation"
    published="$key_directory/generations/$generation"
    ${pkgs.coreutils}/bin/install -d -o root -g kvm -m 0750 "$staging"
    for image in root docker; do
      ${pkgs.coreutils}/bin/cp --reflink=auto --sparse=always -- \
        "$directory/images/$image.img" "$staging/$image.base.raw"
      ${pkgs.coreutils}/bin/chown root:kvm "$staging/$image.base.raw"
      ${pkgs.coreutils}/bin/chmod 0440 "$staging/$image.base.raw"
    done
    ${lib.getExe pkgs.jq} -n \
      --arg schema herdr-microvm-template-v1 \
      --arg key "$template_key" \
      --arg generation "$generation" \
      --arg runner ${lib.escapeShellArg (toString runner)} \
      '{schema: $schema, key: $key, generation: $generation, runner: $runner}' \
      >"$staging/manifest.json"
    ${pkgs.coreutils}/bin/chown root:kvm "$staging/manifest.json"
    ${pkgs.coreutils}/bin/chmod 0440 "$staging/manifest.json"
    : >"$staging/READY"
    ${pkgs.coreutils}/bin/chown root:kvm "$staging/READY"
    ${pkgs.coreutils}/bin/chmod 0440 "$staging/READY"
    ${pkgs.coreutils}/bin/mv "$staging" "$published"
    temporary_link="$key_directory/active.new"
    ${pkgs.coreutils}/bin/ln -s "generations/$generation" "$temporary_link"
    ${pkgs.coreutils}/bin/mv -Tf "$temporary_link" "$active"
    ${pkgs.coreutils}/bin/rm -f "$directory/template-candidate"
    ${pkgs.findutils}/bin/find "$key_directory/generations" \
      -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' |
      ${pkgs.coreutils}/bin/sort -nr |
      ${pkgs.coreutils}/bin/tail -n +3 |
      ${pkgs.gawk}/bin/awk '{print $2}' |
      ${pkgs.findutils}/bin/xargs -r ${pkgs.coreutils}/bin/rm -rf --

  '';
  remove = pkgs.writeShellScript "herdr-microvm-remove" ''
    set -euo pipefail
    ${validateInstance}
    name=$1
    ${pkgs.systemd}/bin/systemctl stop "herdr-microvm@$name.service"
    if ${pkgs.systemd}/bin/systemctl is-active --quiet "herdr-microvm@$name.service"; then
      echo "refusing to remove a running Herdr MicroVM" >&2
      exit 1
    fi
    ${unmountShares} "$name"
    ${pkgs.coreutils}/bin/rm -rf -- "${stateRoot}/workspaces/$name"
    ${pkgs.coreutils}/bin/rm -f -- "/nix/var/nix/gcroots/herdr-sandbox/$name"
  '';
in {
  environment.systemPackages = [runner];

  users = {
    groups.kvm = {};
    users = {
      microvm = {
        isSystemUser = true;
        group = "kvm";
      };
      ${user}.extraGroups = ["kvm"];
    };
  };

  security = {
    pam.loginLimits = [
      {
        domain = "microvm";
        item = "memlock";
        type = "hard";
        value = "infinity";
      }
      {
        domain = "microvm";
        item = "memlock";
        type = "soft";
        value = "infinity";
      }
    ];
    polkit = {
      enable = true;
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id !== "org.freedesktop.systemd1.manage-units" ||
              subject.user !== ${builtins.toJSON user}) {
            return polkit.Result.NOT_HANDLED;
          }

          const unit = action.lookup("unit");
          const verb = action.lookup("verb");
          const allowedUnit = /^(herdr-microvm|herdr-microvm-access|herdr-microvm-attach|herdr-microvm-remove|herdr-microvm-template)@herdr-[0-9a-f]{20}\.service$/.test(unit);
          const allowedVerb = ["start", "stop", "restart"].indexOf(verb) !== -1;
          return allowedUnit && allowedVerb
            ? polkit.Result.YES
            : polkit.Result.NOT_HANDLED;
        });
      '';
    };
  };

  systemd = {
    tmpfiles.rules = [
      "d ${stateRoot} 0755 root root -"
      "d ${stateRoot}/workspaces 0710 root kvm -"
      "d ${templateRoot} 0750 root kvm -"
    ];

    services = {
      "herdr-microvm-prepare@" = {
        description = "Prepare Herdr MicroVM %i";
        restartIfChanged = false;
        partOf = ["herdr-microvm@%i.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${prepare} %i";
          ExecStop = "${unmountShares} %i";
          RemainAfterExit = true;
        };
      };

      "herdr-microvm-virtiofsd@" = {
        description = "VirtioFS daemons for Herdr MicroVM %i";
        restartIfChanged = false;
        requires = ["herdr-microvm-prepare@%i.service"];
        after = ["herdr-microvm-prepare@%i.service"];
        before = ["herdr-microvm@%i.service"];
        partOf = ["herdr-microvm@%i.service"];
        serviceConfig = {
          Type = "notify";
          WorkingDirectory = "${stateRoot}/workspaces/%i";
          ExecStart = "${runner}/bin/virtiofsd-run";
          Restart = "on-failure";
          RestartSec = 1;
          LimitNOFILE = 1048576;
          NotifyAccess = "all";
          PrivateTmp = true;
          KillMode = "mixed";
        };
      };

      "herdr-microvm-relay@" = {
        description = "Host relays for Herdr MicroVM %i";
        restartIfChanged = false;
        requires = ["herdr-microvm-prepare@%i.service"];
        after = ["herdr-microvm-prepare@%i.service"];
        before = ["herdr-microvm@%i.service"];
        partOf = ["herdr-microvm@%i.service"];
        serviceConfig = {
          Type = "simple";
          User = "microvm";
          Group = "kvm";
          UMask = "0007";
          ExecStart = "${relay} %i";
          Restart = "always";
          RestartSec = 1;
        };
      };

      "herdr-microvm@" = {
        description = "Herdr workspace MicroVM %i";
        restartIfChanged = false;
        requires = [
          "herdr-microvm-prepare@%i.service"
          "herdr-microvm-relay@%i.service"
          "herdr-microvm-virtiofsd@%i.service"
        ];
        after = [
          "herdr-microvm-prepare@%i.service"
          "herdr-microvm-relay@%i.service"
          "herdr-microvm-virtiofsd@%i.service"
        ];
        serviceConfig = {
          Type = "notify";
          User = "microvm";
          Group = "kvm";
          UMask = "0007";
          WorkingDirectory = "${stateRoot}/workspaces/%i";
          ExecStartPre = "+${pinRunner} %i";
          ExecStart = "${runner}/bin/microvm-run";
          ExecStartPost = "+${publishVsock} %i";
          ExecStop = "${runner}/bin/microvm-shutdown";
          Restart = "no";
          TimeoutStartSec = 150;
          TimeoutStopSec = 30;
          LimitNOFILE = 1048576;
          LimitMEMLOCK = "infinity";
          NotifyAccess = "all";
          CPUQuota = "400%";
          MemoryMax = "10G";
          MemorySwapMax = 0;
          TasksMax = 2048;
        };
      };

      "herdr-microvm-access@" = {
        description = "Publish the transport socket for Herdr MicroVM %i";
        requires = ["herdr-microvm@%i.service"];
        after = ["herdr-microvm@%i.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${publishVsock} %i";
        };
      };

      "herdr-microvm-attach@" = {
        description = "Mark Herdr MicroVM %i as user-attached";
        restartIfChanged = false;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${markAttached} %i";
        };
      };

      "herdr-microvm-template@" = {
        description = "Publish immutable template from Herdr MicroVM %i";
        restartIfChanged = false;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${publishTemplate} %i";
          TimeoutStartSec = 900;
        };
      };

      "herdr-microvm-remove@" = {
        description = "Remove Herdr MicroVM %i";
        conflicts = ["herdr-microvm@%i.service"];
        before = ["herdr-microvm@%i.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${remove} %i";
        };
      };
    };
  };
}
