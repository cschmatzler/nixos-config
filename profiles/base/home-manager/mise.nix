{pkgs, ...}: {
  programs.mise = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    globalConfig = {
      env = {
        KERL_CONFIGURE_OPTIONS = "--with-termcap --with-ssl=${pkgs.openssl.dev}";
        CPPFLAGS = "-I${pkgs.ncurses.dev}/include -I${pkgs.openssl.dev}/include";
        LDFLAGS = "-L${pkgs.ncurses.out}/lib -L${pkgs.openssl.out}/lib";
        PKG_CONFIG_PATH = "${pkgs.ncurses.dev}/lib/pkgconfig:${pkgs.openssl.dev}/lib/pkgconfig";
      };
    };
  };
}
