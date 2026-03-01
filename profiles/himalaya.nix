{pkgs, ...}: {
	programs.himalaya = {
		enable = true;
		package = pkgs.writeShellApplication {
			name = "himalaya";
			runtimeInputs = [pkgs.himalaya];
			text = ''
				exec env RUST_LOG="warn,imap_codec::response=error" ${pkgs.himalaya}/bin/himalaya "$@"
			'';
		};
	};

	accounts.email = {
		accounts.icloud = {
			primary = true;
			address = "christoph@schmatzler.com";
			userName = "christoph.schmatzler@icloud.com";
			realName = "Christoph Schmatzler";
			passwordCommand = ["cat" "/run/secrets/tahani-email-password"];
			imap = {
				host = "imap.mail.me.com";
				port = 993;
				tls.enable = true;
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
