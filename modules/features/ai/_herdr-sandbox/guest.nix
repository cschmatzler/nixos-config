{
  authorizedKeys,
  brokerPort,
  credentialToken,
  egressPort,
  userHome,
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  workspaceUser = "agent";
  workspaceHome = "/home/${workspaceUser}";
  stateDirectory = "/var/lib/herdr";
  ubuntuRoot = "${stateDirectory}/ubuntu";
  metadata = "${stateDirectory}/workspace.json";
  proxyCaBundle = "${stateDirectory}/proxy-ca-bundle.pem";
  proxyUrl = "http://127.0.0.1:${toString egressPort}";
  ubuntuRootfs = pkgs.fetchurl {
    url = "https://cloud-images.ubuntu.com/minimal/releases/noble/release-20260801/ubuntu-24.04-minimal-cloudimg-amd64-root.tar.xz";
    hash = "sha256-0lPfSTsoxlalJvU7NHoKXC4eMsp21NV2zBf65QgFhgs=";
  };
  githubGatewayCertificate =
    pkgs.runCommand "herdr-github-gateway-certificate" {
      nativeBuildInputs = [pkgs.openssl];
    } ''
      mkdir -p "$out"
      openssl genpkey -algorithm EC \
        -pkeyopt ec_paramgen_curve:P-256 -out "$out/ca.key"
      openssl req -x509 -new -key "$out/ca.key" -sha256 -days 3650 \
        -subj "/CN=Herdr GitHub Gateway CA" -out "$out/ca.crt"
      openssl genpkey -algorithm EC \
        -pkeyopt ec_paramgen_curve:P-256 -out "$out/server.key"
      openssl req -new -key "$out/server.key" \
        -subj "/CN=api.github.com" -out "$out/server.csr"
      cat > "$out/extensions" <<'EOF'
      basicConstraints=critical,CA:FALSE
      keyUsage=critical,digitalSignature,keyEncipherment
      extendedKeyUsage=serverAuth
      subjectAltName=DNS:api.github.com,DNS:github.com
      EOF
      openssl x509 -req -in "$out/server.csr" \
        -CA "$out/ca.crt" -CAkey "$out/ca.key" -CAcreateserial \
        -days 3650 -sha256 -extfile "$out/extensions" -out "$out/server.crt"
    '';
  githubGateway = pkgs.writeText "herdr-github-gateway.mjs" ''
    import fs from "node:fs";
    import http from "node:http";
    import https from "node:https";

    const routes = new Map([
      ["api.github.com", "/github_api"],
      ["github.com", "/github_web"],
    ]);
    const blockedHeaders = new Set([
      "authorization",
      "connection",
      "host",
      "proxy-authorization",
      "proxy-connection",
      "transfer-encoding",
      "upgrade",
    ]);

    const server = https.createServer({
      cert: fs.readFileSync("${githubGatewayCertificate}/server.crt"),
      key: fs.readFileSync("${githubGatewayCertificate}/server.key"),
    }, (request, response) => {
      const host = (request.headers.host ?? "").split(":", 1)[0]?.toLowerCase();
      const route = host === undefined ? undefined : routes.get(host);
      if (route === undefined || request.url === undefined) {
        response.writeHead(403).end();
        return;
      }
      const headers = Object.fromEntries(
        Object.entries(request.headers).filter(([name]) => !blockedHeaders.has(name.toLowerCase())),
      );
      const chunks = [];
      let size = 0;
      request.on("data", (chunk) => {
        size += chunk.length;
        if (size > 16 * 1024 * 1024) request.destroy();
        else chunks.push(chunk);
      });
      request.on("end", () => {
        const body = Buffer.concat(chunks);
        const upstream = http.request({
          host: "127.0.0.1",
          port: ${toString egressPort},
          method: request.method,
          path: `''${route}''${request.url}`,
          headers: {
            ...headers,
            authorization: "Bearer ${credentialToken}",
            connection: "close",
            "content-length": String(body.length),
            host: "127.0.0.1:${toString egressPort}",
          },
        }, (upstreamResponse) => {
          response.writeHead(upstreamResponse.statusCode ?? 502, upstreamResponse.headers);
          upstreamResponse.pipe(response);
        });
        upstream.on("error", () => response.writeHead(502).end());
        upstream.end(body);
      });
    });
    server.listen(443, "127.0.0.1");
  '';
  vsockRelay = pkgs.writeShellScript "herdr-sandbox-vsock-relay" ''
    set -euo pipefail
    cleanup() {
      trap - EXIT INT TERM
      kill "$broker_pid" "$egress_pid" 2>/dev/null || true
      wait "$broker_pid" "$egress_pid" 2>/dev/null || true
    }
    trap cleanup EXIT INT TERM

    ${pkgs.socat}/bin/socat \
      "TCP-LISTEN:${toString brokerPort},bind=127.0.0.1,reuseaddr,fork" \
      "VSOCK-CONNECT:2:${toString brokerPort}" &
    broker_pid=$!
    ${pkgs.socat}/bin/socat \
      "TCP-LISTEN:${toString egressPort},bind=0.0.0.0,reuseaddr,fork" \
      "VSOCK-CONNECT:2:${toString egressPort}" &
    egress_pid=$!

    wait -n "$broker_pid" "$egress_pid"
  '';
  prepareContainer = pkgs.writeShellScript "herdr-sandbox-prepare-container" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [pkgs.xz]}:$PATH
    umask 0022

    if [ ! -e ${ubuntuRoot}/.herdr-rootfs ]; then
      rm -rf ${ubuntuRoot}
      mkdir -p ${ubuntuRoot}
      ${pkgs.gnutar}/bin/tar \
        --extract --xz --numeric-owner --xattrs \
        --file ${ubuntuRootfs} --directory ${ubuntuRoot}
      : > ${ubuntuRoot}/etc/machine-id
      rm -f ${ubuntuRoot}/var/lib/dbus/machine-id

      mkdir -p ${ubuntuRoot}/etc/sysusers.d
      cat > ${ubuntuRoot}/etc/sysusers.d/herdr-workspace.conf <<'EOF'
    g agent 1000
    u agent 1000:1000 "Herdr workspace" /home/agent /bin/bash
    m agent sudo
    EOF
      ${pkgs.systemd}/bin/systemd-sysusers --root=${ubuntuRoot}
      mkdir -p ${ubuntuRoot}${workspaceHome}
      chown 1000:1000 ${ubuntuRoot}${workspaceHome}

      cat > ${ubuntuRoot}/etc/sudoers.d/herdr-workspace <<'EOF'
    agent ALL=(ALL) NOPASSWD: ALL
    EOF
      chmod 0440 ${ubuntuRoot}/etc/sudoers.d/herdr-workspace
      printf 'herdr-workspace\n' > ${ubuntuRoot}/etc/hostname

      mkdir -p \
        ${ubuntuRoot}/usr/local/sbin \
        ${ubuntuRoot}/etc/systemd/system/multi-user.target.wants \
        ${ubuntuRoot}/etc/systemd/system/docker.service.d
      cat > ${ubuntuRoot}/usr/local/sbin/herdr-container-bootstrap <<'EOF'
    #!/bin/sh
    set -eu
    export DEBIAN_FRONTEND=noninteractive
    export HTTP_PROXY=http://127.0.0.1:${toString egressPort}
    export HTTPS_PROXY=$HTTP_PROXY
    export http_proxy=$HTTP_PROXY
    export https_proxy=$HTTP_PROXY
    update-ca-certificates
    if ! command -v docker >/dev/null 2>&1; then
      apt-get update
      apt-get install -y --no-install-recommends docker.io
    fi
    usermod -aG docker agent
    systemctl daemon-reload
    systemctl enable --now docker.service
    EOF
      chmod 0755 ${ubuntuRoot}/usr/local/sbin/herdr-container-bootstrap
      cat > ${ubuntuRoot}/etc/systemd/system/herdr-container-bootstrap.service <<'EOF'
    [Unit]
    Description=Install and configure the Herdr workspace runtime
    After=network.target

    [Service]
    Type=oneshot
    ExecStart=/usr/local/sbin/herdr-container-bootstrap
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target
    EOF
      ln -sfn ../herdr-container-bootstrap.service \
        ${ubuntuRoot}/etc/systemd/system/multi-user.target.wants/herdr-container-bootstrap.service
      cat > ${ubuntuRoot}/etc/systemd/system/docker.service.d/proxy.conf <<'EOF'
    [Service]
    Environment="HTTP_PROXY=http://127.0.0.1:${toString egressPort}"
    Environment="HTTPS_PROXY=http://127.0.0.1:${toString egressPort}"
    Environment="NO_PROXY=127.0.0.1,localhost"
    EOF

      for unit in \
        cloud-config.service \
        cloud-final.service \
        cloud-init-local.service \
        cloud-init.service \
        systemd-networkd-wait-online.service
      do
        ln -sfn /dev/null "${ubuntuRoot}/etc/systemd/system/$unit"
      done
      touch ${ubuntuRoot}/.herdr-rootfs
    fi

    chmod 0755 ${ubuntuRoot}${workspaceHome}
    mkdir -p \
      ${ubuntuRoot}${workspaceHome}/workspace \
      ${ubuntuRoot}${workspaceHome}/.local/state/herdr-sandbox \
      ${ubuntuRoot}/nix/var/nix \
      ${ubuntuRoot}/usr/local/share/ca-certificates
    chown -R 1000:1000 \
      ${ubuntuRoot}${workspaceHome}/workspace \
      ${ubuntuRoot}${workspaceHome}/.local
    if [ -r ${stateDirectory}/imported-cache.json ]; then
      ${pkgs.coreutils}/bin/install -o 1000 -g 1000 -m 0600 \
        ${stateDirectory}/imported-cache.json \
        ${ubuntuRoot}${workspaceHome}/.local/state/herdr-sandbox/imported-cache.json
    fi
    cp ${githubGatewayCertificate}/ca.crt \
      ${ubuntuRoot}/usr/local/share/ca-certificates/herdr-github-gateway.crt
    if ! ${pkgs.gnugrep}/bin/grep -q '^127\.0\.0\.1 api\.github\.com github\.com$' ${ubuntuRoot}/etc/hosts; then
      printf '\n127.0.0.1 api.github.com github.com\n' >> ${ubuntuRoot}/etc/hosts
    fi

    checkout=$(${lib.getExe pkgs.jq} -er '.checkoutPath' ${metadata})
    canonical=$(${pkgs.coreutils}/bin/realpath -m -- "$checkout")
    case "$canonical" in
      /home/*) ;;
      *) echo "workspace checkout path is outside /home" >&2; exit 2 ;;
    esac
    if [ "$canonical" != "$checkout" ]; then
      echo "workspace checkout path is not canonical" >&2
      exit 2
    fi
    mkdir -p "${ubuntuRoot}$(dirname "$checkout")" "${ubuntuRoot}$checkout"
  '';
  runContainer = pkgs.writeShellScript "herdr-sandbox-run-container" ''
    set -euo pipefail
    checkout=$(${lib.getExe pkgs.jq} -er '.checkoutPath' ${metadata})
    canonical=$(${pkgs.coreutils}/bin/realpath -m -- "$checkout")
    if [ "$canonical" != "$checkout" ]; then
      echo "workspace checkout path is not canonical" >&2
      exit 2
    fi
    case "$canonical" in
      /home/*) ;;
      *) echo "workspace checkout path is outside /home" >&2; exit 2 ;;
    esac
    exec ${pkgs.systemd}/bin/systemd-nspawn \
      --quiet \
      --boot \
      --notify-ready=yes \
      --keep-unit \
      --capability=all \
      --private-users=no \
      --register=yes \
      --machine=herdr-workspace \
      --hostname=herdr-workspace \
      --directory=${ubuntuRoot} \
      --bind=/nix/store \
      --bind=/nix/var/nix \
      --bind=${stateDirectory}/checkout:${workspaceHome}/workspace \
      --bind=${stateDirectory}/checkout:"$checkout" \
      --bind-ro=/run/herdr/cache/npm:${userHome}/.pi/agent/npm \
      --bind-ro=/run/herdr/cache/git:${userHome}/.pi/agent/git \
      --bind-ro=/run/herdr/cache/nix:/run/herdr/cache/nix-host \
      --bind-ro=/run/herdr/cache/playwright:${userHome}/.cache/ms-playwright \
      --bind=/var/lib/docker \
      --setenv=HTTP_PROXY=${proxyUrl} \
      --setenv=HTTPS_PROXY=${proxyUrl} \
      --setenv=http_proxy=${proxyUrl} \
      --setenv=https_proxy=${proxyUrl} \
      --setenv=NO_PROXY=127.0.0.1,localhost \
      --setenv=no_proxy=127.0.0.1,localhost
  '';
  guestProvision = pkgs.writeShellScriptBin "herdr-guest-provision" ''
    set -euo pipefail
    operation=''${1:-}
    ${pkgs.coreutils}/bin/install -d -o root -g users -m 0710 ${stateDirectory}
    exec 9>${stateDirectory}/provision.lock
    ${pkgs.util-linux}/bin/flock 9
    case "$operation" in
      metadata)
        temporary=${metadata}.new
        previous_checkout=$(${lib.getExe pkgs.jq} -r '.checkoutPath // empty' ${metadata} 2>/dev/null || true)
        previous_branch=$(${lib.getExe pkgs.jq} -r '.branch // empty' ${metadata} 2>/dev/null || true)
        cat > "$temporary"
        ${lib.getExe pkgs.jq} -e '
          (.checkoutPath | type == "string" and startswith("/home/") and (contains("/../") | not)) and
          (.branch | type == "string" and length > 0) and
          (.originUrl | type == "string")
        ' "$temporary" >/dev/null
        checkout=$(${lib.getExe pkgs.jq} -er '.checkoutPath' "$temporary")
        canonical=$(${pkgs.coreutils}/bin/realpath -m -- "$checkout")
        if [ "$canonical" != "$checkout" ]; then
          echo "workspace checkout path is not canonical" >&2
          exit 2
        fi
        branch=$(${lib.getExe pkgs.jq} -er '.branch' "$temporary")
        chmod 0600 "$temporary"
        mv -f "$temporary" ${metadata}
        if [ -e ${stateDirectory}/template-base ] &&
          { [ "$previous_checkout" != "$checkout" ] ||
            [ "$previous_branch" != "$branch" ] ||
            [ ! -e ${stateDirectory}/seed-complete ]; }; then
          : > ${stateDirectory}/seed-required
        fi
        ;;
      stop-container)
        ${pkgs.systemd}/bin/systemctl stop herdr-workspace-container.service
        ${pkgs.systemd}/bin/systemctl is-active --quiet herdr-workspace-container.service && exit 1 || true
        ;;
      cache-ready)
        devenv_fingerprint=''${2:-}
        dependency_fingerprint=''${3:-}
        ${lib.getExe pkgs.jq} -e \
          --arg devenv "$devenv_fingerprint" \
          --arg dependencies "$dependency_fingerprint" '
            .devenv == $devenv and .dependencies == $dependencies
          ' ${stateDirectory}/imported-cache.json >/dev/null 2>&1 || {
          test "$(cat ${stateDirectory}/checkout/.devenv/.herdr-sandbox-devenv-v3 2>/dev/null)" = "$devenv_fingerprint"
          test "$(cat ${stateDirectory}/checkout/node_modules/.herdr-sandbox-dependencies-v3 2>/dev/null)" = "$dependency_fingerprint"
        }
        ;;
      cache-seed)
        devenv_fingerprint=''${2:-}
        dependency_fingerprint=''${3:-}
        archive_digest=''${4:-}
        expected_expanded=''${5:-}
        for value in "$devenv_fingerprint" "$dependency_fingerprint" "$archive_digest"; do
          if ! printf '%s' "$value" | ${pkgs.gnugrep}/bin/grep -Eq '^[a-f0-9]{64}$'; then
            echo "invalid cache seed metadata" >&2
            exit 2
          fi
        done
        if ! printf '%s' "$expected_expanded" | ${pkgs.gnugrep}/bin/grep -Eq '^[0-9]+$' ||
          [ "$expected_expanded" -gt 8589934592 ]; then
          echo "invalid expanded cache size" >&2
          exit 2
        fi
        archive=${stateDirectory}/cache-seed.tar.zst
        staging=${stateDirectory}/cache-seed.$$
        rm -rf "$staging" "$archive"
        cat > "$archive"
        actual_digest=$(${pkgs.coreutils}/bin/sha256sum "$archive" | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)
        if [ "$actual_digest" != "$archive_digest" ]; then
          rm -f "$archive"
          echo "cache seed digest mismatch" >&2
          exit 1
        fi
        archive_size=$(${pkgs.coreutils}/bin/stat -c %s "$archive")
        available=$(${pkgs.coreutils}/bin/df --output=avail -B1 ${stateDirectory} | ${pkgs.coreutils}/bin/tail -1)
        if [ "$archive_size" -gt $((4 * 1024 * 1024 * 1024)) ] ||
          [ "$available" -lt $((archive_size + expected_expanded + 2 * 1024 * 1024 * 1024)) ]; then
          rm -f "$archive"
          echo "cache seed exceeds the workspace disk budget" >&2
          exit 1
        fi
        mkdir -m 0700 "$staging"
        ${pkgs.gnutar}/bin/tar \
          --extract --zstd --restrict \
          --no-same-owner --no-same-permissions \
          --file "$archive" --directory "$staging"
        manifest="$staging/.herdr-cache-manifest.json"
        ${lib.getExe pkgs.jq} -e \
          --arg devenv "$devenv_fingerprint" \
          --arg dependencies "$dependency_fingerprint" \
          --arg expanded "$expected_expanded" '
            .schema == "herdr-microvm-cache-v3" and
            .devenv == $devenv and
            .dependencies == $dependencies and
            (.entries | type == "number" and . <= 2000000) and
            (.expandedBytes == ($expanded | tonumber))
          ' "$manifest" >/dev/null
        actual_expanded=$(${pkgs.coreutils}/bin/du -sb "$staging" | ${pkgs.coreutils}/bin/cut -f 1)
        [ "$actual_expanded" -le $((expected_expanded + 1048576)) ] || {
          echo "expanded cache size mismatch" >&2
          exit 1
        }
        installed=()
        committed=false
        cleanup_cache_seed() {
          if [ "$committed" != true ]; then
            for target in "''${installed[@]}"; do rm -rf -- "$target"; done
          fi
          rm -rf "$staging" "$archive"
        }
        trap cleanup_cache_seed EXIT
        for relative in .devenv node_modules; do
          source="$staging/$relative"
          target=${stateDirectory}/checkout/$relative
          if [ -e "$source" ] && [ ! -e "$target" ]; then
            chown -R ${workspaceUser}:users "$source"
            mv "$source" "$target"
            installed+=("$target")
          fi
        done
        while IFS= read -r -d $'\0' source; do
          relative=''${source#"$staging/"}
          target=${stateDirectory}/checkout/$relative
          case "$relative" in
            node_modules) continue ;;
            */node_modules) ;;
            *) echo "invalid dependency cache path" >&2; exit 1 ;;
          esac
          if [ ! -e "$target" ]; then
            mkdir -p "$(dirname "$target")"
            chown -R ${workspaceUser}:users "$source"
            mv "$source" "$target"
            installed+=("$target")
          fi
        done < <(${pkgs.findutils}/bin/find "$staging" -depth -type d -name node_modules -print0)
        ${pkgs.coreutils}/bin/install -m 0600 "$manifest" ${stateDirectory}/imported-cache.json
        committed=true
        trap - EXIT
        cleanup_cache_seed
        ;;
      seeded)
        test ! -e ${stateDirectory}/seed-required
        ${lib.getExe pkgs.git} -C ${stateDirectory}/checkout rev-parse --git-dir >/dev/null 2>&1
        ;;
      seed)
        bundle=${stateDirectory}/seed.bundle
        cat > "$bundle"
        branch=$(${lib.getExe pkgs.jq} -er '.branch' ${metadata})
        origin=$(${lib.getExe pkgs.jq} -er '.originUrl' ${metadata})
        if ${lib.getExe pkgs.git} -C ${stateDirectory}/checkout rev-parse --git-dir >/dev/null 2>&1; then
          ${pkgs.util-linux}/bin/runuser -u ${workspaceUser} -- \
            ${lib.getExe pkgs.git} -C ${stateDirectory}/checkout fetch "$bundle" \
            '+refs/heads/*:refs/remotes/herdr-seed/*' \
            '+refs/tags/*:refs/tags/*'
          ${pkgs.util-linux}/bin/runuser -u ${workspaceUser} -- \
            ${lib.getExe pkgs.git} -C ${stateDirectory}/checkout clean -fdx \
            -e .devenv -e node_modules -e '*/node_modules'
          ${pkgs.util-linux}/bin/runuser -u ${workspaceUser} -- \
            ${lib.getExe pkgs.git} -C ${stateDirectory}/checkout \
            switch -C "$branch" "refs/remotes/herdr-seed/$branch"
        else
          rm -rf ${stateDirectory}/checkout
          ${lib.getExe pkgs.git} clone "$bundle" ${stateDirectory}/checkout
          chown -R ${workspaceUser}:users ${stateDirectory}/checkout
          if ! ${pkgs.util-linux}/bin/runuser -u ${workspaceUser} -- \
              ${lib.getExe pkgs.git} -C ${stateDirectory}/checkout switch "$branch"; then
            ${pkgs.util-linux}/bin/runuser -u ${workspaceUser} -- \
              ${lib.getExe pkgs.git} -C ${stateDirectory}/checkout \
              switch --track -c "$branch" "origin/$branch"
          fi
        fi
        if [ -n "$origin" ]; then
          ${pkgs.util-linux}/bin/runuser -u ${workspaceUser} -- \
            ${lib.getExe pkgs.git} -C ${stateDirectory}/checkout remote set-url origin "$origin"
        fi
        rm -f "$bundle" ${stateDirectory}/seed-required
        : > ${stateDirectory}/seed-complete
        ;;
      template-sanitize)
        ${pkgs.systemd}/bin/systemctl stop herdr-workspace-container.service
        ${pkgs.systemd}/bin/systemctl is-active --quiet herdr-workspace-container.service && exit 1 || true
        rm -f ${metadata} ${stateDirectory}/seed-complete
        : > ${stateDirectory}/template-base
        rm -rf \
          ${ubuntuRoot}${workspaceHome}/.pi \
          ${ubuntuRoot}${workspaceHome}/.claude \
          ${ubuntuRoot}${workspaceHome}/.config/herdr \
          ${ubuntuRoot}${workspaceHome}/.docker \
          ${ubuntuRoot}${workspaceHome}/.local/state/herdr-sandbox/capability \
          ${ubuntuRoot}${workspaceHome}/.local/state/herdr-sandbox/credential-sync-digest \
          ${ubuntuRoot}${workspaceHome}/.local/state/herdr-sandbox/setup-done \
          ${ubuntuRoot}${workspaceHome}/.local/state/herdr-sandbox/resume-boot \
          ${ubuntuRoot}${workspaceHome}/.local/state/herdr-sandbox/devenv-environment.fish \
          ${ubuntuRoot}${workspaceHome}/.local/state/herdr-sandbox/panes \
          ${ubuntuRoot}${workspaceHome}/.local/state/herdr-sandbox/relay
        rm -rf /var/lib/docker/*
        rm -f /etc/ssh/ssh_host_* ${ubuntuRoot}/etc/ssh/ssh_host_*
        : > /etc/machine-id
        : > ${ubuntuRoot}/etc/machine-id
        : > /var/lib/herdr-template-sanitized
        ;;
      start)
        ${pkgs.systemd}/bin/systemctl start herdr-workspace-container.service
        ;;
      proxy-ca)
        temporary_cert=${stateDirectory}/proxy-ca.crt.new
        temporary_bundle=${proxyCaBundle}.new
        cat > "$temporary_cert"
        ${lib.getExe pkgs.openssl} x509 -in "$temporary_cert" -noout
        cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt "$temporary_cert" > "$temporary_bundle"
        chmod 0600 "$temporary_cert" "$temporary_bundle"
        mv -f "$temporary_cert" ${stateDirectory}/proxy-ca.crt
        mv -f "$temporary_bundle" ${proxyCaBundle}
        ;;
      ready)
        ${pkgs.systemd}/bin/systemctl is-active --quiet herdr-workspace-container.service
        for _attempt in $(${pkgs.coreutils}/bin/seq 300); do
          if ${pkgs.systemd}/bin/systemd-run \
              --quiet --wait --pipe --collect --machine=herdr-workspace \
              /bin/systemctl is-active --quiet \
              herdr-container-bootstrap.service docker.service; then
            exit 0
          fi
          sleep 1
        done
        echo "Ubuntu workspace services did not become ready" >&2
        exit 1
        ;;
      *)
        echo "usage: herdr-guest-provision metadata|proxy-ca|stop-container|cache-ready|cache-seed|seeded|seed|start|ready|template-sanitize" >&2
        exit 2
        ;;
    esac
  '';
in {
  system.stateVersion = "25.11";
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  nix.settings = {
    extra-substituters = ["https://devenv.cachix.org"];
    extra-trusted-public-keys = [
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
    ssl-cert-file = proxyCaBundle;
  };
  networking = {
    hostName = "herdr-workspace";
    useDHCP = false;
    useNetworkd = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [egressPort];
    };
  };

  microvm = {
    hypervisor = "cloud-hypervisor";
    vcpu = 4;
    mem = 8192;
    interfaces = [];
    writableStoreOverlay = "/var/lib/herdr/nix-store-overlay";
    socket = "run/control.sock";
    cloud-hypervisor.extraArgs = [
      "--vsock"
      "cid=3,socket=run/notify.vsock"
    ];
    volumes = [
      {
        image = "images/root.img";
        size = 20 * 1024;
        label = "herdr-root";
        mountPoint = "/";
        fsType = "ext4";
      }
      {
        image = "images/docker.img";
        size = 20 * 1024;
        label = "herdr-docker";
        mountPoint = "/var/lib/docker";
        fsType = "ext4";
      }
    ];
    shares = [
      {
        tag = "store";
        socket = "run/virtiofs-store.sock";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        proto = "virtiofs";
        readOnly = true;
        cache = "always";
        posixAcl = false;
      }
      {
        tag = "cache-npm";
        socket = "run/virtiofs-cache-npm.sock";
        source = "shares/npm";
        mountPoint = "/run/herdr/cache/npm";
        proto = "virtiofs";
        readOnly = true;
        cache = "always";
        posixAcl = false;
      }
      {
        tag = "cache-git";
        socket = "run/virtiofs-cache-git.sock";
        source = "shares/git";
        mountPoint = "/run/herdr/cache/git";
        proto = "virtiofs";
        readOnly = true;
        cache = "always";
        posixAcl = false;
      }
      {
        tag = "cache-nix";
        socket = "run/virtiofs-cache-nix.sock";
        source = "shares/nix";
        mountPoint = "/run/herdr/cache/nix";
        proto = "virtiofs";
        readOnly = true;
        cache = "always";
        posixAcl = false;
      }
      {
        tag = "cache-playwright";
        socket = "run/virtiofs-cache-playwright.sock";
        source = "shares/playwright";
        mountPoint = "/run/herdr/cache/playwright";
        proto = "virtiofs";
        readOnly = true;
        cache = "always";
        posixAcl = false;
      }
    ];
  };

  boot.kernelModules = [
    "br_netfilter"
    "bridge"
    "nf_nat"
    "overlay"
    "veth"
  ];
  documentation.enable = false;
  programs.fish.enable = true;
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    coreutils
    findutils
    fish
    git
    gnutar
    guestProvision
    jq
    openssl
    nodejs_24
    procps
    socat
    systemd
    util-linux
    zstd
  ];

  users = {
    mutableUsers = false;
    users.${workspaceUser} = {
      isNormalUser = true;
      uid = 1000;
      home = workspaceHome;
      createHome = true;
      shell = pkgs.bashInteractive;
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = authorizedKeys;
    };
  };

  security.sudo.extraRules = [
    {
      users = [workspaceUser];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  services.openssh = {
    enable = true;
    settings = {
      AllowUsers = [workspaceUser];
      DisableForwarding = true;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };

  systemd.services = {
    nix-daemon = {
      after = ["herdr-sandbox-vsock-relay.service"];
      requires = ["herdr-sandbox-vsock-relay.service"];
      environment = {
        HTTP_PROXY = proxyUrl;
        HTTPS_PROXY = proxyUrl;
        NO_PROXY = "127.0.0.1,localhost";
        http_proxy = proxyUrl;
        https_proxy = proxyUrl;
        no_proxy = "127.0.0.1,localhost";
        NIX_SSL_CERT_FILE = proxyCaBundle;
        SSL_CERT_FILE = proxyCaBundle;
      };
    };

    herdr-sandbox-vsock-relay = {
      description = "Herdr broker and egress relays";
      wantedBy = ["multi-user.target"];
      before = [
        "herdr-github-gateway.service"
        "herdr-workspace-container.service"
      ];
      serviceConfig = {
        Type = "simple";
        ExecStart = vsockRelay;
        Restart = "always";
        RestartSec = 1;
      };
    };

    herdr-github-gateway = {
      description = "Credential-isolating GitHub gateway";
      wantedBy = ["multi-user.target"];
      after = ["herdr-sandbox-vsock-relay.service"];
      requires = ["herdr-sandbox-vsock-relay.service"];
      before = ["herdr-workspace-container.service"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.nodejs_24} ${githubGateway}";
        Restart = "always";
        RestartSec = 1;
        NoNewPrivileges = true;
      };
    };

    herdr-workspace-container = {
      description = "Persistent Ubuntu environment for the Herdr workspace";
      wantedBy = ["multi-user.target"];
      after = [
        "herdr-github-gateway.service"
        "herdr-sandbox-vsock-relay.service"
      ];
      requires = [
        "herdr-github-gateway.service"
        "herdr-sandbox-vsock-relay.service"
      ];
      unitConfig.ConditionPathExists = metadata;
      serviceConfig = {
        Type = "notify";
        NotifyAccess = "all";
        ExecStartPre = prepareContainer;
        ExecStart = runContainer;
        Restart = "on-failure";
        RestartSec = 1;
        KillMode = "mixed";
        TimeoutStartSec = 300;
        Delegate = true;
      };
    };
  };
}
