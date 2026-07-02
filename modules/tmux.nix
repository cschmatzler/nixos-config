{...}: let
  theme = (import ./_lib/theme.nix).catppuccinLatte;
in {
  den.aspects.tmux.homeManager = {
    config,
    pkgs,
    lib,
    ...
  }: let
    clipboardTool =
      if pkgs.stdenv.isDarwin
      then "pbcopy"
      else "${pkgs.wl-clipboard}/bin/wl-copy";
    tmuxConf = import ./_tmux/default.nix {inherit pkgs theme clipboardTool;};
  in {
    home.packages = lib.optional (!pkgs.stdenv.isDarwin) pkgs.wl-clipboard;

    programs.tmux = {
      enable = true;
      sensibleOnTop = false;
      extraConfig = tmuxConf;
      plugins = with pkgs.tmuxPlugins; [
        vim-tmux-navigator
        resurrect
        continuum
      ];
    };
  };
}
