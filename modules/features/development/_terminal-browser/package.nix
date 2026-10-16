{pkgs}: let
  inherit (pkgs) lib;

  release = rec {
    version = "0.13.4";
    tag = "v${version}";
    platform = "linux-x64";
    system = "x86_64-linux";
    url = "https://github.com/zenbu-labs/terminal-browser/releases/download/${tag}/terminal-browser-${platform}.tar.gz";
    sha256 = "6277daaabab16711ab3f1961cdffad9efac5e70ac55d5076e2c86496d649d3a4";
    stateIdentity = "terminal-browser-nix";
    paths = {
      electron = "electron/pixel";
      cli = "cli/dist/main.js";
      browser = "browser/dist/main.js";
      agent = "agent-browser/bin/agent-browser";
      launcher = "bin/terminal-browser";
      sandbox = "electron/chrome-sandbox";
      apparmor = "scripts/apparmor.sh";
      skill = "skills/default/terminal-browser";
    };
  };

  neededLibraries = with pkgs; [
    stdenv.cc.cc.lib
    glib
    nspr
    nss
    at-spi2-core
    cups
    dbus
    cairo
    gtk3
    pango
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libgbm
    expat
    libxcb
    libxkbcommon
    systemd
    alsa-lib
  ];

  # dlopen libraries do not appear in the bundle's DT_NEEDED entries.
  dynamicLibraries = with pkgs; [
    fontconfig
    gdk-pixbuf
    gtk4
    libGL
    libxcursor
    libdrm
    libxshmfence
    libnotify
    libsecret
    libpulseaudio
    pipewire
    pciutils
    speechd-minimal
  ];
in
  pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "terminal-browser";
    inherit (release) version;
    src = pkgs.fetchurl {
      inherit (release) url sha256;
    };

    nativeBuildInputs = with pkgs; [
      autoPatchelfHook
      makeWrapper
      wrapGAppsHook3
      python3
    ];
    buildInputs = neededLibraries ++ dynamicLibraries;
    runtimeDependencies = map lib.getLib dynamicLibraries;
    autoPatchelfFlags = ["--preserve-origin"];
    dontWrapGApps = true;
    sourceRoot = "terminal-browser";
    dontBuild = true;
    dontStrip = true;
    strictDeps = true;

    installPhase = ''
      runHook preInstall
      root="$out/libexec/terminal-browser"
      mkdir -p "$root" "$out/bin" "$out/share/terminal-browser"
      cp -a . "$root/"

      python3 ${./patch-bundle.py} "$root" \
        ${lib.escapeShellArg (builtins.toJSON release)} \
        ${lib.escapeShellArg pkgs.runtimeShell} \
        ${./skill-policy.md}

      rm "$root/${release.paths.launcher}"
      ln -s ../libexec/terminal-browser/${release.paths.launcher} "$out/bin/terminal-browser"
      ln -s "$root/${release.paths.skill}" "$out/share/terminal-browser/skill"

      # Use the host's non-root namespace sandbox, not a setuid helper.
      chmod 0755 "$root/${release.paths.sandbox}"
      rm "$root/${release.paths.apparmor}"
      runHook postInstall
    '';

    preFixup = ''
      root="$out/libexec/terminal-browser"
      # GApps arguments exist only after preFixupPhases. Herdr reentry uses
      # this same launcher, so privacy and environment policy belong here.
      makeShellWrapper "$root/${release.paths.electron}" "$root/${release.paths.launcher}" \
        --run 'umask 077' \
        --set TERMINAL_BROWSER_DIST_ROOT "$root" \
        --set ELECTRON_RUN_AS_NODE 1 \
        --set TERMINAL_BROWSER_AGENT "$root/${release.paths.agent}" \
        --set TERMINAL_BROWSER_NO_TELEMETRY 1 \
        --prefix PATH : "$out/bin:${lib.makeBinPath [pkgs.coreutils pkgs.procps]}" \
        --add-flags "$root/${release.paths.cli}" \
        "''${gappsWrapperArgs[@]}"
      addAutoPatchelfSearchPath "$root/electron"
    '';

    passthru.skillPath = "${finalAttrs.finalPackage}/share/terminal-browser/skill";
    meta = {
      description = "Patched Electron browser rendered inside a terminal";
      homepage = "https://github.com/zenbu-labs/terminal-browser";
      platforms = [release.system];
      mainProgram = "terminal-browser";
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
