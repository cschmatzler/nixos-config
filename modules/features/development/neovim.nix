{inputs, ...}: {
  flake-file.inputs = {
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  den.aspects.neovim.homeManager = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      inputs.nixvim.homeModules.nixvim
      ./_neovim/default.nix
    ];

    home.sessionVariables = {
      EDITOR = "nvim";
      MANPAGER = "nvim +Man!";
    };

    programs = {
      nixvim = {
        version.enableNixpkgsReleaseCheck = false;
      };

      fish.functions.fvim = ''
        if test (count $argv) -eq 0
          ${pkgs.fd}/bin/fd -H -t f | ${pkgs.fzf}/bin/fzf --header "Open File in Vim" --preview "${pkgs.coreutils}/bin/cat {}" | ${pkgs.findutils}/bin/xargs ${config.programs.nixvim.build.package}/bin/nvim
        else
          set -l query (string join " " $argv)
          ${pkgs.fd}/bin/fd -H -t f | ${pkgs.fzf}/bin/fzf --header "Open File in Vim" --preview "${pkgs.coreutils}/bin/cat {}" -q "$query" | ${pkgs.findutils}/bin/xargs ${config.programs.nixvim.build.package}/bin/nvim
        end
      '';
    };
  };
}
