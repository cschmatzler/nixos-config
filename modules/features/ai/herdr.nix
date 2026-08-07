_: let
  renderHerdrConfig = import ./_herdr/render-config.nix;
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
    herdrPackage = inputs'.herdr.packages.herdr;
    pluginId = "gh-pr-workspace";
    pluginRoot = "${config.xdg.configHome}/herdr/local-plugins/${pluginId}";
  in {
    home.packages = with pkgs; [
      bun
      gh
      git
      herdrPackage
    ];

    home.file = {
      ".config/herdr/config.toml".text = renderHerdrConfig {inherit theme;};
      ".config/herdr/local-plugins/${pluginId}" = {
        source = ./_herdr/plugins/gh-pr-workspace;
        recursive = true;
      };
    };

    home.activation.linkHerdrGithubPrWorkspace = lib.hm.dag.entryAfter ["linkGeneration"] ''
      plugin_state="$(${herdrPackage}/bin/herdr plugin list --plugin ${pluginId} --json)"
      if printf '%s' "$plugin_state" \
        | ${pkgs.jq}/bin/jq -e --arg root ${lib.escapeShellArg pluginRoot} \
          '.result.plugins[0].plugin_root == $root' >/dev/null; then
        run ${herdrPackage}/bin/herdr plugin enable ${pluginId}
      else
        if printf '%s' "$plugin_state" \
          | ${pkgs.jq}/bin/jq -e '.result.plugins | length > 0' >/dev/null; then
          run ${herdrPackage}/bin/herdr plugin unlink ${pluginId}
        fi
        run ${herdrPackage}/bin/herdr plugin link ${lib.escapeShellArg pluginRoot}
      fi
    '';
  };
}
