{...}: let
	local = import ./_lib/local.nix;
in {
	den.aspects.email.homeManager = {pkgs, ...}: {
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

		accounts.email = {
			accounts.${local.user.emails.personal} = {
				primary = true;
				maildir.path = local.user.emails.personal;
				address = local.user.emails.personal;
				userName = local.user.emails.icloud;
				realName = local.user.fullName;
				passwordCommand = ["${pkgs.coreutils}/bin/cat" (local.secretPath "tahani-email-password")];
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
			};
		};
	};
}
