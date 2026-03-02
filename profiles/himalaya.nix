{pkgs, ...}: {
	programs.himalaya = {
		enable = true;
		package =
			pkgs.writeShellApplication {
				name = "himalaya";
				runtimeInputs = [pkgs.coreutils pkgs.himalaya];
				text = ''
					exec env RUST_LOG="warn,imap_codec::response=error" ${pkgs.himalaya}/bin/himalaya "$@"
				'';
			};
	};

	accounts.email = {
		accounts."christoph@schmatzler.com" = {
			primary = true;
			maildir.path = "christoph@schmatzler.com";
			address = "christoph@schmatzler.com";
			userName = "christoph.schmatzler@icloud.com";
			realName = "Christoph Schmatzler";
			passwordCommand = ["cat" "/run/secrets/tahani-email-password"];
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
		};
	};
}
