_: let
  theme = (import ../../_lib/theme.nix).rosePineDawn;
in {
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
    tomlFormat = pkgs.formats.toml {};
    herdrPackage = inputs'.herdr.packages.herdr;
    defaultShell =
      if config.herdrSandbox.shell == null
      then "fish"
      else config.herdrSandbox.shell;
    herdrConfig = import ./_herdr/config.nix {inherit theme defaultShell;};
    pluginId = "gh-pr-workspace";
    pluginRoot = "${config.xdg.configHome}/herdr/local-plugins/${pluginId}";
  in {
    options.herdrSandbox.shell = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      internal = true;
      description = "Host command used to attach Herdr panes to an isolated workspace";
    };

    config.home = {
      packages = with pkgs; [
        bun
        gh
        git
        herdrPackage
      ];

      file = {
        ".config/herdr/config.toml".source = tomlFormat.generate "herdr-config.toml" herdrConfig;
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
