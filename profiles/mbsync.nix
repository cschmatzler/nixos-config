{...}: {
	programs.mbsync.enable = true;
	services.mbsync = {
		enable = true;
		frequency = "*:0/5";
	};

	accounts.email.accounts."christoph@schmatzler.com" = {
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
}
