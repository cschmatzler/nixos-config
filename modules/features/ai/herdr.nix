_: {
  flake-file.inputs.herdr = {
    url = "github:ogulcancelik/herdr";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.herdr.homeManager = {
    config,
    inputs',
    lib,
    pkgs,
    ...
  }: let
    herdrPackage = inputs'.herdr.packages.herdr.overrideAttrs (old: {
      patches = (old.patches or []) ++ [./_herdr/subagent-visibility.patch];
    });
    pluginId = "gh-pr-workspace";
    pluginRoot = "${config.xdg.configHome}/herdr/local-plugins/${pluginId}";
  in {
    home = {
      packages = with pkgs; [
        bun
        gh
        git
        herdrPackage
      ];

      file = {
        ".config/herdr/config.toml".source = (pkgs.formats.toml {}).generate "herdr-config.toml" (import ./_herdr/config.nix {
          theme = (import ../../_lib/theme.nix).rosePineDawn;
        });
        ".config/herdr/local-plugins/${pluginId}" = {
          source = ./_herdr/plugins/gh-pr-workspace;
          recursive = true;
        };
      };

      activation.linkHerdrGithubPrWorkspace = lib.hm.dag.entryAfter ["linkGeneration"] ''
        canonical_plugin_root="$(${pkgs.coreutils}/bin/dirname \
          "$(${pkgs.coreutils}/bin/readlink -f \
            ${lib.escapeShellArg "${pluginRoot}/herdr-plugin.toml"})")"
        plugin_state="$(${herdrPackage}/bin/herdr plugin list --plugin ${pluginId} --json)"
        if printf '%s' "$plugin_state" \
          | ${pkgs.jq}/bin/jq -e --arg root "$canonical_plugin_root" \
            '.result.plugins[0].plugin_root == $root' >/dev/null; then
          run ${herdrPackage}/bin/herdr plugin enable ${pluginId}
        else
          run ${herdrPackage}/bin/herdr plugin link ${lib.escapeShellArg pluginRoot}
        fi
      '';
    };
  };
}
