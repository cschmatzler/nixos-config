_: let
  local = import ../../_lib/local.nix;
  passwordFile = "/run/secrets/tahani-email-password";
in {
  den.aspects.email.os.sops.secrets = {
    tahani-email-password = {
      format = "binary";
      owner = local.user.name;
      sopsFile = ../../../secrets/tahani-email-password;
    };
  };

  den.aspects.email.homeManager = {pkgs, ...}: {
    programs = {
      aerc = {
        enable = true;
        extraConfig.general.unsafe-accounts-conf = true;
      };

      himalaya = {
        enable = true;
        package = pkgs.writeShellApplication {
          name = "himalaya";
          runtimeInputs = [pkgs.bash pkgs.coreutils pkgs.himalaya];
          text = ''
            exec env RUST_LOG="warn,imap_codec::response=error" ${pkgs.himalaya}/bin/himalaya "$@"
          '';
        };
      };

      mbsync.enable = true;
    };

    services.mbsync = {
      enable = true;
      frequency = "*:0/5";
    };

    accounts.email.accounts.${local.user.emails.personal} = {
      primary = true;
      maildir.path = local.user.emails.personal;
      address = local.user.emails.personal;
      userName = local.user.emails.icloud;
      realName = local.user.fullName;
      passwordCommand = ["${pkgs.coreutils}/bin/cat" passwordFile];
      folders = {
        inbox = "INBOX";
        drafts = "Drafts";
        sent = "Sent Messages";
        trash = "Deleted Messages";
      };
      smtp = {
        host = "smtp.mail.me.com";
        port = 587;
        tls.useStartTls = true;
      };
      himalaya.enable = true;
      mbsync = {
        enable = true;
        create = "both";
        expunge = "both";
      };
      imap = {
        host = "imap.mail.me.com";
        port = 993;
        tls.enable = true;
      };
      aerc.enable = true;
    };
  };
}
