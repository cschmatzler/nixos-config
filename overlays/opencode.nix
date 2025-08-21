final: prev: {
  opencode = prev.opencode.overrideAttrs (oldAttrs: rec {
    version = "0.5.12";

    src = prev.fetchFromGitHub {
      owner = "sst";
      repo = "opencode";
      tag = "v${version}";
      hash = "sha256-iPv6rATpIpf2j81Ud4OSWOt0ZSR0sAYBhBRrQpOH1Bs=";
    };

    tui = prev.buildGoModule {
      pname = "opencode-tui";
      inherit version src;
      modRoot = "packages/tui";
      vendorHash = "sha256-acDXCL7ZQYW5LnEqbMgDwpTbSgtf4wXnMMVtQI1Dv9s=";
      subPackages = ["cmd/opencode"];

      env.CGO_ENABLED = 0;

      ldflags = [
        "-s"
        "-X=main.Version=${version}"
      ];

      installPhase = ''
        runHook preInstall
        install -Dm755 $GOPATH/bin/opencode $out/bin/tui
        runHook postInstall
      '';
    };

    node_modules = prev.stdenvNoCC.mkDerivation {
      pname = "opencode-node_modules";
      inherit version src;

      impureEnvVars =
        prev.lib.fetchers.proxyImpureEnvVars
        ++ [
          "GIT_PROXY_COMMAND"
          "SOCKS_SERVER"
        ];

      nativeBuildInputs = [
        prev.bun
        prev.writableTmpDirAsHomeHook
      ];

      dontConfigure = true;

      buildPhase = ''
        runHook preBuild

        export BUN_INSTALL_CACHE_DIR=$(mktemp -d)

        # Disable post-install scripts to avoid shebang issues
        bun install \
          --filter=opencode \
          --force \
          --frozen-lockfile \
          --ignore-scripts \
          --no-progress \
          --production

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p $out/node_modules
        cp -R ./node_modules $out

        runHook postInstall
      '';

      dontFixup = true;

      outputHash = "sha256-hznCg/7c9uNV7NXTkb6wtn3EhJDkGI7yZmSIA2SqX7g=";
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
    };

    buildPhase = ''
      runHook preBuild

      bun build \
        --define OPENCODE_TUI_PATH="'${oldAttrs.tui}/bin/tui'" \
        --define OPENCODE_VERSION="'${version}'" \
        --compile \
        --target=${
        {
          "aarch64-darwin" = "bun-darwin-arm64";
          "aarch64-linux" = "bun-linux-arm64";
          "x86_64-darwin" = "bun-darwin-x64";
          "x86_64-linux" = "bun-linux-x64";
        }.${
          prev.stdenvNoCC.hostPlatform.system
        }
      } \
        --outfile=opencode \
        ./packages/opencode/src/index.ts \

      runHook postBuild
    '';
  });
}

