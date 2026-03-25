{
	config,
	inputs',
	lib,
	pkgs,
	...
}: let
	notabilityScripts = ./notability;
	webdavRoot = "/home/cschmatzler/.local/share/notability-ingest/webdav-root";
	dataRoot = "/home/cschmatzler/.local/share/notability-ingest";
	stateRoot = "/home/cschmatzler/.local/state/notability-ingest";
	notesRoot = "/home/cschmatzler/Notes";
	commonPath = [
		inputs'.llm-agents.packages.pi
		pkgs.qmd
		pkgs.coreutils
		pkgs.inotify-tools
		pkgs.nushell
		pkgs.poppler-utils
		pkgs.rclone
		pkgs.sqlite
		pkgs.util-linux
		pkgs.zk
	];
	commonEnvironment = {
		HOME = "/home/cschmatzler";
		NOTABILITY_ARCHIVE_ROOT = "${dataRoot}/archive";
		NOTABILITY_DATA_ROOT = dataRoot;
		NOTABILITY_DB_PATH = "${stateRoot}/db.sqlite";
		NOTABILITY_NOTES_DIR = notesRoot;
		NOTABILITY_RENDER_ROOT = "${dataRoot}/rendered-pages";
		NOTABILITY_SESSIONS_ROOT = "${stateRoot}/sessions";
		NOTABILITY_STATE_ROOT = stateRoot;
		NOTABILITY_TRANSCRIPT_ROOT = "${stateRoot}/transcripts";
		NOTABILITY_WEBDAV_ROOT = webdavRoot;
		XDG_CONFIG_HOME = "/home/cschmatzler/.config";
	};
in {
	sops.secrets.tahani-notability-webdav-password = {
		sopsFile = ../../../../secrets/tahani-notability-webdav-password;
		format = "binary";
		owner = "cschmatzler";
		path = "/run/secrets/tahani-notability-webdav-password";
	};

	home-manager.users.cschmatzler = {
		home.packages = [
			pkgs.qmd
			pkgs.poppler-utils
			pkgs.rclone
			pkgs.sqlite
			pkgs.zk
		];
		home.file.".config/qmd/index.yml".text = ''
			collections:
			  notes:
			    path: ${notesRoot}
			    pattern: "**/*.md"
		'';
	};

	systemd.tmpfiles.rules = [
		"d ${notesRoot} 0755 cschmatzler users -"
		"d ${dataRoot} 0755 cschmatzler users -"
		"d ${webdavRoot} 0755 cschmatzler users -"
		"d ${dataRoot}/archive 0755 cschmatzler users -"
		"d ${dataRoot}/rendered-pages 0755 cschmatzler users -"
		"d ${stateRoot} 0755 cschmatzler users -"
		"d ${stateRoot}/jobs 0755 cschmatzler users -"
		"d ${stateRoot}/jobs/queued 0755 cschmatzler users -"
		"d ${stateRoot}/jobs/running 0755 cschmatzler users -"
		"d ${stateRoot}/jobs/failed 0755 cschmatzler users -"
		"d ${stateRoot}/jobs/done 0755 cschmatzler users -"
		"d ${stateRoot}/jobs/results 0755 cschmatzler users -"
		"d ${stateRoot}/sessions 0755 cschmatzler users -"
		"d ${stateRoot}/transcripts 0755 cschmatzler users -"
	];

	services.caddy.virtualHosts."tahani.manticore-hippocampus.ts.net".extraConfig = ''
		tls {
			get_certificate tailscale
		}
		handle /notability* {
			reverse_proxy 127.0.0.1:9980
		}
	'';

	systemd.services.notability-webdav = {
		description = "Notability WebDAV landing zone";
		wantedBy = ["multi-user.target"];
		after = ["network.target"];
		path = commonPath;
		environment =
			commonEnvironment
			// {
				NOTABILITY_WEBDAV_ADDR = "127.0.0.1:9980";
				NOTABILITY_WEBDAV_BASEURL = "/notability";
				NOTABILITY_WEBDAV_PASSWORD_FILE = config.sops.secrets.tahani-notability-webdav-password.path;
				NOTABILITY_WEBDAV_USER = "notability";
			};
		serviceConfig = {
			ExecStart = "${pkgs.nushell}/bin/nu ${notabilityScripts}/webdav.nu";
			Group = "users";
			Restart = "always";
			RestartSec = 5;
			User = "cschmatzler";
			WorkingDirectory = "/home/cschmatzler";
		};
	};

	systemd.services.notability-watch = {
		description = "Watch and ingest Notability WebDAV uploads";
		wantedBy = ["multi-user.target"];
		after = ["notability-webdav.service"];
		requires = ["notability-webdav.service"];
		path = commonPath;
		environment = commonEnvironment;
		serviceConfig = {
			ExecStart = "${pkgs.nushell}/bin/nu ${notabilityScripts}/watch.nu";
			Group = "users";
			Restart = "always";
			RestartSec = 5;
			User = "cschmatzler";
			WorkingDirectory = "/home/cschmatzler";
		};
	};
}
