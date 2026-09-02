_: {
  den.aspects.openssh.nixos = {
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
    programs.mosh = {
      enable = true;
      openFirewall = true;
    };
  };
}
