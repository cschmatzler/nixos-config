{
	config,
	pkgs,
	lib,
	...
}:
with lib; let
	tomlFormat = pkgs.formats.toml {};
	account = config.accounts.email.accounts.icloud;
	maildirPath = account.maildir.absPath;
in {
	home.packages = [pkgs.neverest];

	xdg.configFile."neverest/config.toml".source = tomlFormat.generate "neverest-config.toml" {
		accounts.icloud = {
			default = true;

			folder.filters = "all";

			left = {
				backend = {
					type = "maildir";
					root-dir = maildirPath;
				};
				folder = {
					aliases = {
						inbox = "INBOX";
						drafts = "Drafts";
						sent = "Sent Messages";
						trash = "Deleted Messages";
					};
					permissions = {
						create = true;
						delete = true;
					};
				};
				flag.permissions.update = true;
				message.permissions = {
					create = true;
					delete = true;
				};
			};

			right = {
				backend = {
					type = "imap";
					host = "imap.mail.me.com";
					port = 993;
					encryption = "tls";
					login = account.userName;
					auth = {
						type = "password";
						cmd = concatStringsSep " " account.passwordCommand;
					};
				};
				folder = {
					aliases = {
						inbox = "INBOX";
						drafts = "Drafts";
						sent = "Sent Messages";
						trash = "Deleted Messages";
					};
					permissions.delete = false;
				};
				message.permissions.delete = false;
			};
		};
	};

	systemd.user.services.neverest-sync = {
		Unit = {
			Description = "Neverest email sync";
		};
		Service = {
			Type = "oneshot";
			ExecStart = "${pkgs.neverest}/bin/neverest sync";
		};
	};

	systemd.user.timers.neverest-sync = {
		Unit = {
			Description = "Neverest email sync timer";
		};
		Timer = {
			OnBootSec = "1min";
			OnUnitActiveSec = "5min";
			Persistent = true;
		};
		Install = {
			WantedBy = ["timers.target"];
		};
	};
}
