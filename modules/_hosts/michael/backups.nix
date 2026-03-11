{
	config,
	lib,
	pkgs,
	...
}: {
	services.restic.backups.gitea = {
		repository = "s3:s3.eu-central-003.backblazeb2.com/michael-gitea-repositories";
		paths = ["/var/lib/gitea"];
		exclude = [
			"/var/lib/gitea/log"
			"/var/lib/gitea/data/gitea.db"
			"/var/lib/gitea/data/gitea.db-shm"
			"/var/lib/gitea/data/gitea.db-wal"
		];
		passwordFile = config.sops.secrets.michael-gitea-restic-password.path;
		environmentFile = config.sops.secrets.michael-gitea-restic-env.path;
		pruneOpts = [
			"--keep-daily 7"
			"--keep-weekly 4"
			"--keep-monthly 6"
		];
		timerConfig = {
			OnCalendar = "daily";
			Persistent = true;
			RandomizedDelaySec = "1h";
		};
	};

	systemd.services.restic-backups-gitea = {
		wants = ["restic-init-gitea.service"];
		after = ["restic-init-gitea.service"];
		serviceConfig = {
			User = lib.mkForce "gitea";
			Group = lib.mkForce "gitea";
		};
	};

	systemd.services.restic-init-gitea = {
		description = "Initialize Restic repository for Gitea backups";
		wantedBy = ["multi-user.target"];
		after = ["network-online.target"];
		wants = ["network-online.target"];
		path = [pkgs.restic];
		serviceConfig = {
			Type = "oneshot";
			User = "gitea";
			Group = "gitea";
			RemainAfterExit = true;
			EnvironmentFile = config.sops.secrets.michael-gitea-restic-env.path;
		};
		script = ''
			export RESTIC_PASSWORD=$(cat ${config.sops.secrets.michael-gitea-restic-password.path})
			restic -r s3:s3.eu-central-003.backblazeb2.com/michael-gitea-repositories snapshots &>/dev/null || \
				restic -r s3:s3.eu-central-003.backblazeb2.com/michael-gitea-repositories init
		'';
	};
}
