_: {
  den.aspects.tmux.homeManager = {
    pkgs,
    lib,
    ...
  }: {
    home.packages = lib.optional (!pkgs.stdenv.hostPlatform.isDarwin) pkgs.wl-clipboard;

    programs.tmux = {
      enable = true;
      sensibleOnTop = false;
      extraConfig = import ./_tmux/default.nix {
        inherit pkgs;
        theme = (import ../../_lib/theme.nix).rosePineDawn;
        clipboardTool =
          if pkgs.stdenv.hostPlatform.isDarwin
          then "pbcopy"
          else "${pkgs.wl-clipboard}/bin/wl-copy";
      };
      plugins = with pkgs.tmuxPlugins; [
        vim-tmux-navigator
        resurrect
        continuum
      ];
    };
  };
}
