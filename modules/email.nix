{...}: let
  local = import ./_lib/local.nix;
  passwordSecret = "tahani-email-password";
  gmailPasswordSecret = "tahani-gmail-password";
in {
  den.aspects.email.homeManager = {pkgs, ...}: {
    programs.aerc = {
      enable = true;
      extraConfig.general.unsafe-accounts-conf = true;
    };

    programs.himalaya = {
      enable = true;
      package = pkgs.writeShellApplication {
        name = "himalaya";
        runtimeInputs = [pkgs.bash pkgs.coreutils pkgs.himalaya];
        text = ''
          exec env RUST_LOG="warn,imap_codec::response=error" ${pkgs.himalaya}/bin/himalaya "$@"
        '';
      };
    };

    home.packages = [
      (pkgs.writeShellApplication {
        name = "migrate-gmail-to-icloud-inbox";
        runtimeInputs = with pkgs; [coreutils imapsync];
        text = ''
          set -eu

          gmail_pass="${local.secretPath gmailPasswordSecret}"
          icloud_pass="${local.secretPath passwordSecret}"

          if [ ! -r "$gmail_pass" ]; then
            echo "Missing readable Gmail password secret: $gmail_pass" >&2
            exit 1
          fi

          if [ ! -r "$icloud_pass" ]; then
            echo "Missing readable iCloud password secret: $icloud_pass" >&2
            exit 1
          fi

          dry_args=(--dry)
          if [ "''${1:-}" = "--run" ]; then
            dry_args=()
            shift
          fi

          common_args=(
            --gmail1
            --host1 imap.gmail.com
            --ssl1
            --user1 "${local.user.emails.personal}"
            --passfile1 "$gmail_pass"
            --host2 imap.mail.me.com
            --ssl2
            --user2 "${local.user.emails.icloud}"
            --passfile2 "$icloud_pass"
            --skipcrossduplicates
            --useheader Message-Id
            --syncinternaldates
          )

          echo "Syncing Gmail folders except All Mail..."
          imapsync \
            "''${dry_args[@]}" \
            "''${common_args[@]}" \
            --automap \
            --exclude '^\\[Gmail\\]/All Mail$|^\\[Gmail\\]/Important$|^\\[Gmail\\]/Starred$' \
            --f1f2 INBOX=INBOX \
            --f1f2 "[Gmail]/Drafts=Drafts" \
            --f1f2 "[Gmail]/Sent Mail=Sent Messages" \
            --f1f2 "[Gmail]/Spam=Junk" \
            --f1f2 "[Gmail]/Trash=Deleted Messages" \
            --f1f2 "Newsletters=Newsletters and Marketing" \
            "$@"

          echo "Syncing Gmail All Mail to iCloud Archive..."
          imapsync \
            "''${dry_args[@]}" \
            "''${common_args[@]}" \
            --folder "[Gmail]/All Mail" \
            --f1f2 "[Gmail]/All Mail=Archive" \
            "$@"
        '';
      })
    ];

    programs.mbsync.enable = true;
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
      passwordCommand = ["${pkgs.coreutils}/bin/cat" (local.secretPath passwordSecret)];
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
