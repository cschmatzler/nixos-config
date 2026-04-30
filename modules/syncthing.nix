{lib, ...}: let
	local = import ./_lib/local.nix;
	secretLib = import ./_lib/secrets.nix {inherit lib;};
	user = local.user.name;
	deviceIds = {
		tahani = "6B7OZZF-TEAMUGO-FBOELXP-Z4OY7EU-5ZHLB5T-V6Z3UDB-Q2DYR43-QBYW6QM";
		janet = "MJ3WG4R-REHF6JK-LCTHR2Y-4Q3Q2JE-YHO6CPW-6ZADQIX-KURTNMA-LSIPDQT";
	};

	mkHome = isDarwin:
		if isDarwin
		then "/Users/${user}"
		else "/home/${user}";

	mkSecrets = {
		host,
		isDarwin,
		linkToConfig ? false,
	}: let
		homeDir = mkHome isDarwin;
	in {
		"${host}-syncthing-cert" =
			secretLib.mkUserBinarySecret ({
					name = "${host}-syncthing-cert";
					sopsFile = ../secrets/${host}-syncthing-cert;
				}
				// lib.optionalAttrs linkToConfig {
					path = "${homeDir}/.config/syncthing/cert.pem";
				});
		"${host}-syncthing-key" =
			secretLib.mkUserBinarySecret ({
					name = "${host}-syncthing-key";
					sopsFile = ../secrets/${host}-syncthing-key;
				}
				// lib.optionalAttrs linkToConfig {
					path = "${homeDir}/.config/syncthing/key.pem";
				});
	};

	mkSettings = homeDir: {
		devices = {
			tahani = {
				id = deviceIds.tahani;
				addresses = ["tcp://${local.tailscaleHost "tahani"}:22000"];
			};
			janet = {
				id = deviceIds.janet;
				addresses = ["tcp://${local.tailscaleHost "janet"}:22000"];
			};
		};

		folders = {
			Clearly = {
				path = "${homeDir}/Clearly";
				devices = ["tahani" "janet"];
			};
		};

		options = {
			globalAnnounceEnabled = false;
			localAnnounceEnabled = false;
			relaysEnabled = false;
		};
	};

	mkUpdateConfig = {
		pkgs,
		configDir,
		guiAddress,
		settings,
	}: let
		cleanedConfig = lib.converge (lib.filterAttrsRecursive (_: v: v != null && v != {})) settings;
		isUnixGui = (builtins.substring 0 1 guiAddress) == "/";
		curlAddressArgs = path:
			if isUnixGui
			then "--unix-socket ${guiAddress} http://.${path}"
			else "${guiAddress}${path}";
		devices = lib.mapAttrsToList (_: device: device // {deviceID = device.id;}) settings.devices;
		folders =
			lib.mapAttrsToList (_: folder:
					folder
					// {
						devices =
							map (
								device:
									if builtins.isString device
									then {deviceId = settings.devices.${device}.id;}
									else if builtins.isAttrs device
									then {deviceId = settings.devices.${device.name}.id;} // device
									else throw "Invalid type for devices in Syncthing folder; expected string or attrset."
							)
							folder.devices;
					})
			settings.folders;
		jq = "${pkgs.jq}/bin/jq";
	in
		pkgs.writers.writeBash "merge-syncthing-config" (
			''
				set -efu
				umask 0077

				curl() {
				    while
				        ! ${pkgs.libxml2}/bin/xmllint \
				            --xpath 'string(configuration/gui/apikey)' \
				            ${configDir}/config.xml \
				            >"$TMPDIR/api_key"
				    do sleep 1; done
				    (printf "X-API-Key: "; cat "$TMPDIR/api_key") >"$TMPDIR/headers"
				    ${pkgs.curl}/bin/curl -sSLk -H "@$TMPDIR/headers" \
				        --retry 1000 --retry-delay 1 --retry-all-errors \
				        "$@"
				}
			''
			+ (lib.pipe {
					devs = {
						new_conf_IDs = map (v: v.id) devices;
						GET_IdAttrName = "deviceID";
						conf = devices;
						baseAddress = curlAddressArgs "/rest/config/devices";
					};
					dirs = {
						new_conf_IDs = map (v: v.id) folders;
						GET_IdAttrName = "id";
						conf = folders;
						baseAddress = curlAddressArgs "/rest/config/folders";
					};
				} [
					(lib.mapAttrs (
							conf_type: s: let
								upserts =
									map (new_cfg: let
											jsonPreSecretsFile =
												pkgs.writeTextFile {
													name = "${conf_type}-${new_cfg.id}-conf.json";
													text = builtins.toJSON new_cfg;
												};
										in ''
											${jq} . ${jsonPreSecretsFile} | curl --json @- -X POST ${s.baseAddress}
										'')
									s.conf;
							in
								(lib.concatStringsSep "\n" upserts)
								+ ''
									stale_${conf_type}_ids="$(curl -X GET ${s.baseAddress} | ${jq} \
									  --argjson new_ids ${lib.escapeShellArg (builtins.toJSON s.new_conf_IDs)} \
									  --raw-output \
									  '[.[].${s.GET_IdAttrName}] - $new_ids | .[]'
									)"
									for id in ''${stale_${conf_type}_ids}; do
									  >&2 echo "Deleting stale ${conf_type}: $id"
									  curl -X DELETE ${s.baseAddress}/$id
									done
								''
						))
					builtins.attrValues
					(lib.concatStringsSep "\n")
				])
			+ (lib.pipe cleanedConfig [
					builtins.attrNames
					(lib.subtractLists ["folders" "devices"])
					(map (subOption: ''
								curl -X PUT -d ${lib.escapeShellArg (builtins.toJSON cleanedConfig.${subOption})} ${curlAddressArgs "/rest/config/${subOption}"}
							''))
					(lib.concatStringsSep "\n")
				])
			+ ''
				if curl ${curlAddressArgs "/rest/config/restart-required"} |
				   ${jq} -e .requiresRestart > /dev/null; then
				    curl -X POST ${curlAddressArgs "/rest/system/restart"}
				fi
			''
		);
in {
	den.aspects.syncthing.nixos = {config, ...}: let
		host = config.networking.hostName;
		homeDir = mkHome false;
	in {
		sops.secrets =
			mkSecrets {
				inherit host;
				isDarwin = false;
			};

		services.syncthing = {
			enable = true;
			openDefaultPorts = true;
			dataDir = "${homeDir}/.local/share/syncthing";
			configDir = "${homeDir}/.config/syncthing";
			cert = config.sops.secrets."${host}-syncthing-cert".path;
			key = config.sops.secrets."${host}-syncthing-key".path;
			inherit user;
			group = "users";
			guiAddress = "0.0.0.0:8384";
			overrideFolders = true;
			overrideDevices = true;
			settings = mkSettings homeDir;
		};
	};

	den.aspects.syncthing.darwin = {
		config,
		pkgs,
		...
	}: let
		host = config.networking.hostName;
		homeDir = mkHome true;
		configDir = "${homeDir}/.config/syncthing";
		guiAddress = "0.0.0.0:8384";
		settings = mkSettings homeDir;
		updateConfig =
			mkUpdateConfig {
				inherit pkgs configDir guiAddress settings;
			};
	in {
		sops.secrets =
			mkSecrets {
				inherit host;
				isDarwin = true;
				linkToConfig = true;
			};

		environment.systemPackages = [pkgs.syncthing];

		launchd.user.agents.syncthing.serviceConfig = {
			ProgramArguments = [
				"${pkgs.syncthing}/bin/syncthing"
				"--no-browser"
				"--gui-address=${guiAddress}"
				"--config=${configDir}"
				"--data=${configDir}"
			];
			EnvironmentVariables = {
				STNORESTART = "yes";
				STNOUPGRADE = "yes";
			};
			KeepAlive = true;
			RunAtLoad = true;
			ProcessType = "Background";
			StandardOutPath = "${configDir}/syncthing.log";
			StandardErrorPath = "${configDir}/syncthing.log";
		};

		launchd.user.agents.syncthing-init.serviceConfig = {
			ProgramArguments = ["${updateConfig}"];
			RunAtLoad = true;
			KeepAlive = false;
			ProcessType = "Background";
			StandardOutPath = "${configDir}/syncthing-init.log";
			StandardErrorPath = "${configDir}/syncthing-init.log";
		};
	};
}
