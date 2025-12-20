{
	config,
	lib,
	modulesPath,
	hostname,
	inputs,
	pkgs,
	user,
	constants,
	...
}: {
	imports = [
		(modulesPath + "/installer/scan/not-detected.nix")
		(modulesPath + "/profiles/qemu-guest.nix")
		./disk-config.nix
		./hardware-configuration.nix
		../../profiles/core.nix
		../../profiles/fail2ban.nix
		../../profiles/nixos.nix
		../../profiles/postgresql.nix
		../../profiles/tailscale.nix
		inputs.disko.nixosModules.disko
		inputs.sops-nix.nixosModules.sops
	];

	sops.secrets.mindy-pgbackrest = {
		sopsFile = ../../secrets/mindy-pgbackrest;
		format = "binary";
		owner = "postgres";
		group = "postgres";
	};

	environment.systemPackages = [
		pkgs.pgbackrest
		(pkgs.writeShellScriptBin "pgbackrest-archive-push" ''
			set -a
			source /run/secrets/mindy-pgbackrest
			set +a
			exec ${pkgs.pgbackrest}/bin/pgbackrest --stanza=main archive-push "$1"
		'')
	];

	services.postgresql.settings.archive_command = lib.mkForce "${pkgs.writeShellScript "pgbackrest-archive-push" ''
		set -a
		source /run/secrets/mindy-pgbackrest
		set +a
		exec ${pkgs.pgbackrest}/bin/pgbackrest --stanza=main archive-push "$1"
	''} %p";

	environment.etc."pgbackrest/pgbackrest.conf".text = ''
		[global]
		repo1-type=s3
		repo1-s3-endpoint=s3.eu-central-003.backblazeb2.com
		repo1-s3-bucket=mindy-pgbackrest
		repo1-s3-region=eu-central-003
		repo1-path=/backups
		repo1-retention-full=7
		repo1-retention-diff=7
		repo1-cipher-type=aes-256-cbc
		compress-type=zst
		compress-level=3
		process-max=2
		log-level-console=info
		log-level-file=detail
		log-path=/var/log/pgbackrest
		spool-path=/var/spool/pgbackrest

		[main]
		pg1-path=/var/lib/postgresql/${config.services.postgresql.package.psqlSchema}
		pg1-user=postgres
	'';

	systemd.services.pgbackrest-stanza-create = {
		description = "pgBackRest Stanza Create";
		after = ["postgresql.service"];
		requires = ["postgresql.service"];
		path = [pkgs.pgbackrest];
		serviceConfig = {
			Type = "oneshot";
			User = "postgres";
			EnvironmentFile = "/run/secrets/mindy-pgbackrest";
			RemainAfterExit = true;
		};
		script = ''
			pgbackrest --stanza=main stanza-create || true
		'';
	};

	systemd.services.pgbackrest-backup = {
		description = "pgBackRest Full Backup";
		after = ["postgresql.service" "pgbackrest-stanza-create.service"];
		requires = ["postgresql.service"];
		wants = ["pgbackrest-stanza-create.service"];
		path = [pkgs.pgbackrest];
		serviceConfig = {
			Type = "oneshot";
			User = "postgres";
			EnvironmentFile = "/run/secrets/mindy-pgbackrest";
		};
		script = ''
			pgbackrest --stanza=main backup --type=full
		'';
	};

	systemd.timers.pgbackrest-backup = {
		wantedBy = ["timers.target"];
		timerConfig = {
			OnCalendar = "daily";
			Persistent = true;
			RandomizedDelaySec = "1h";
		};
	};

	systemd.services.pgbackrest-backup-diff = {
		description = "pgBackRest Differential Backup";
		after = ["postgresql.service" "pgbackrest-stanza-create.service"];
		requires = ["postgresql.service"];
		wants = ["pgbackrest-stanza-create.service"];
		path = [pkgs.pgbackrest];
		serviceConfig = {
			Type = "oneshot";
			User = "postgres";
			EnvironmentFile = "/run/secrets/mindy-pgbackrest";
		};
		script = ''
			pgbackrest --stanza=main backup --type=diff
		'';
	};

	systemd.timers.pgbackrest-backup-diff = {
		wantedBy = ["timers.target"];
		timerConfig = {
			OnCalendar = "hourly";
			Persistent = true;
			RandomizedDelaySec = "5m";
		};
	};

	systemd.tmpfiles.rules = [
		"d /var/lib/pgbackrest 0750 postgres postgres -"
		"d /var/log/pgbackrest 0750 postgres postgres -"
		"d /var/spool/pgbackrest 0750 postgres postgres -"
	];

	home-manager.users.${user} = {
		pkgs,
		lib,
		...
	}: {
		_module.args = {inherit user constants inputs;};
		imports = [
			inputs.nixvim.homeModules.nixvim
			../../profiles/bash.nix
			../../profiles/bat.nix
			../../profiles/direnv.nix
			../../profiles/eza.nix
			../../profiles/fish.nix
			../../profiles/fzf.nix
			../../profiles/git.nix
			../../profiles/home.nix
			../../profiles/jjui.nix
			../../profiles/jujutsu.nix
			../../profiles/lazygit.nix
			../../profiles/neovim
			../../profiles/ripgrep.nix
			../../profiles/ssh.nix
			../../profiles/starship.nix
			../../profiles/zoxide.nix
		];
	};

	services.openssh = {
		enable = true;
		settings = {
			PermitRootLogin = "yes";
			PasswordAuthentication = false;
		};
	};

	virtualisation.docker.enable = true;

	networking.hostName = hostname;
}
