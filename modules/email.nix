{...}: let
	local = import ./_lib/local.nix;
	passwordSecret = "tahani-gmail-password";
in {
	den.aspects.email.homeManager = {pkgs, ...}: {
		programs.aerc = {
			enable = true;
			extraConfig.general.unsafe-accounts-conf = true;
		};

		programs.himalaya = {
			enable = true;
			package =
				pkgs.writeShellApplication {
					name = "himalaya";
					runtimeInputs = [pkgs.bash pkgs.coreutils pkgs.himalaya];
					text = ''
						exec env RUST_LOG="warn,imap_codec::response=error" ${pkgs.himalaya}/bin/himalaya "$@"
					'';
				};
		};

		programs.mbsync.enable = true;
		services.mbsync = {
			enable = true;
			frequency = "*:0/5";
		};

		accounts.email.accounts.${local.user.emails.personal} = {
			primary = true;
			flavor = "gmail.com";
			maildir.path = local.user.emails.personal;
			address = local.user.emails.personal;
			realName = local.user.fullName;
			passwordCommand = ["${pkgs.coreutils}/bin/cat" (local.secretPath passwordSecret)];
			folders = {
				inbox = "INBOX";
				drafts = "[Gmail]/Drafts";
				sent = "[Gmail]/Sent Mail";
				trash = "[Gmail]/Trash";
			};
			smtp.tls.useStartTls = true;
			himalaya.enable = true;
			mbsync = {
				enable = true;
				create = "both";
				expunge = "both";
				extraConfig.account.AuthMechs = "LOGIN";
			};
			aerc = {
				enable = true;
				extraAccounts = {
					archive = "[Gmail]/All Mail";
					"folders-exclude" = "~^\\[Gmail\\]/";
				};
			};
		};
	};
}
