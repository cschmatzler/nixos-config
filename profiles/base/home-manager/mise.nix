{pkgs, ...}: {
  programs.mise = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    globalConfig = {
      env = {
        KERL_CONFIGURE_OPTIONS = "--with-termcap";
        CPPFLAGS = "-I${pkgs.ncurses.dev}/include";
        LDFLAGS = "-L${pkgs.ncurses.out}/lib";
      };
    };
  };
}
