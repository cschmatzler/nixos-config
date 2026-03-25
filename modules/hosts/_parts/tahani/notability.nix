{
	config,
	inputs',
	pkgs,
	...
}: let
	homeDir = "/home/cschmatzler";
	notabilityScripts = ./notability;
	dataRoot = "${homeDir}/.local/share/notability-ingest";
	stateRoot = "${homeDir}/.local/state/notability-ingest";
	notesRoot = "${homeDir}/Notes";
	webdavRoot = "${dataRoot}/webdav-root";
	userPackages = with pkgs; [
		qmd
		poppler-utils
		rclone
		sqlite
		zk
	];
	commonPath = with pkgs;
		[
			inputs'.llm-agents.packages.pi
			coreutils
			inotify-tools
			nushell
			util-linux
		]
		++ userPackages;
	commonEnvironment = {
		HOME = homeDir;
		NOTABILITY_ARCHIVE_ROOT = "${dataRoot}/archive";
		NOTABILITY_DATA_ROOT = dataRoot;
		NOTABILITY_DB_PATH = "${stateRoot}/db.sqlite";
		NOTABILITY_NOTES_DIR = notesRoot;
		NOTABILITY_RENDER_ROOT = "${dataRoot}/rendered-pages";
		NOTABILITY_SESSIONS_ROOT = "${stateRoot}/sessions";
		NOTABILITY_STATE_ROOT = stateRoot;
		NOTABILITY_TRANSCRIPT_ROOT = "${stateRoot}/transcripts";
		NOTABILITY_WEBDAV_ROOT = webdavRoot;
		XDG_CONFIG_HOME = "${homeDir}/.config";
	};
	mkTmpDirRule = path: "d ${path} 0755 cschmatzler users -";
	mkNotabilityService = {
		description,
		script,
		after ? [],
		requires ? [],
		environment ? {},
	}: {
		inherit after description requires;
		wantedBy = ["multi-user.target"];
		path = commonPath;
		environment = commonEnvironment // environment;
		serviceConfig = {
			ExecStart = "${pkgs.nushell}/bin/nu ${notabilityScripts}/${script}";
			Group = "users";
			Restart = "always";
			RestartSec = 5;
			User = "cschmatzler";
			WorkingDirectory = homeDir;
		};
	};
in {
	sops.secrets.tahani-notability-webdav-password = {
		sopsFile = ../../../../secrets/tahani-notability-webdav-password;
		format = "binary";
		owner = "cschmatzler";
		path = "/run/secrets/tahani-notability-webdav-password";
	};

	home-manager.users.cschmatzler = {
		home.packages = userPackages;
		home.file.".config/qmd/index.yml".text = ''
			collections:
			  notes:
			    path: ${notesRoot}
			    pattern: "**/*.md"
		'';
	};

	systemd.tmpfiles.rules =
		builtins.map mkTmpDirRule [
			notesRoot
			dataRoot
			webdavRoot
			"${dataRoot}/archive"
			"${dataRoot}/rendered-pages"
			stateRoot
			"${stateRoot}/jobs"
			"${stateRoot}/jobs/queued"
			"${stateRoot}/jobs/running"
			"${stateRoot}/jobs/failed"
			"${stateRoot}/jobs/done"
			"${stateRoot}/jobs/results"
			"${stateRoot}/sessions"
			"${stateRoot}/transcripts"
		];

	services.caddy.virtualHosts."tahani.manticore-hippocampus.ts.net".extraConfig = ''
		tls {
			get_certificate tailscale
		}
		handle /notability* {
			reverse_proxy 127.0.0.1:9980
		}
	'';

	systemd.services.notability-webdav =
		mkNotabilityService {
			description = "Notability WebDAV landing zone";
			script = "webdav.nu";
			after = ["network.target"];
			environment = {
				NOTABILITY_WEBDAV_ADDR = "127.0.0.1:9980";
				NOTABILITY_WEBDAV_BASEURL = "/notability";
				NOTABILITY_WEBDAV_PASSWORD_FILE = config.sops.secrets.tahani-notability-webdav-password.path;
				NOTABILITY_WEBDAV_USER = "notability";
			};
		};

	systemd.services.notability-watch =
		mkNotabilityService {
			description = "Watch and ingest Notability WebDAV uploads";
			script = "watch.nu";
			after = ["notability-webdav.service"];
			requires = ["notability-webdav.service"];
		};
}
