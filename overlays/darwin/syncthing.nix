final: prev: {
  darwinSyncthingModule = {
    config,
    lib,
    pkgs,
    ...
  }:
    with lib; let
      cfg = config.services.syncthing;
      defaultUser = "syncthing";
      defaultGroup = defaultUser;
      settingsFormat = pkgs.formats.json {};
      cleanedConfig = converge (filterAttrsRecursive (_: v: v != null && v != {})) cfg.settings;

      isUnixGui = (builtins.substring 0 1 cfg.guiAddress) == "/";

      curlAddressArgs = path:
        if isUnixGui
        then "--unix-socket ${cfg.guiAddress} http://.${path}"
        else "${cfg.guiAddress}${path}";

      devices = mapAttrsToList (_: device: device // {deviceID = device.id;}) cfg.settings.devices;
      anyAutoAccept = builtins.any (dev: dev.autoAcceptFolders) devices;

      folders = mapAttrsToList (_: folder:
        folder
        // {
          devices = let
            folderDevices = folder.devices;
          in
            map (
              device:
                if builtins.isString device
                then {deviceId = cfg.settings.devices.${device}.id;}
                else if builtins.isAttrs device
                then {deviceId = cfg.settings.devices.${device.name}.id;} // device
                else throw "Invalid type for devices in folder; expected list or attrset."
            )
            folderDevices;
        }) (filterAttrs (_: folder: folder.enable) cfg.settings.folders);

      jq = "${pkgs.jq}/bin/jq";
      updateConfig = pkgs.writers.writeBash "merge-syncthing-config" (
        ''
          set -efu
          umask 0077

          curl() {
              while
                  ! ${pkgs.libxml2}/bin/xmllint \
                      --xpath 'string(configuration/gui/apikey)' \
                      ${cfg.configDir}/config.xml \
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
              override = cfg.overrideDevices;
              conf = devices;
              baseAddress = curlAddressArgs "/rest/config/devices";
            };
            dirs = {
              new_conf_IDs = map (v: v.id) folders;
              GET_IdAttrName = "id";
              override = cfg.overrideFolders;
              conf = folders;
              baseAddress = curlAddressArgs "/rest/config/folders";
            };
          } [
            (mapAttrs (
              conf_type: s:
                lib.pipe s.conf [
                  (map (
                    new_cfg: let
                      jsonPreSecretsFile = pkgs.writeTextFile {
                        name = "${conf_type}-${new_cfg.id}-conf-pre-secrets.json";
                        text = builtins.toJSON new_cfg;
                      };
                      injectSecretsJqCmd =
                        {
                          "devs" = "${jq} .";
                          "dirs" = let
                            folder = new_cfg;
                            devicesWithSecrets = lib.pipe folder.devices [
                              (lib.filter (device: (builtins.isAttrs device) && device ? encryptionPasswordFile))
                              (map (device: {
                                deviceId = device.deviceId;
                                variableName = "secret_${builtins.hashString "sha256" device.encryptionPasswordFile}";
                                secretPath = device.encryptionPasswordFile;
                              }))
                            ];
                            jqUpdates =
                              map (device: ''
                                .devices[] |= (
                                  if .deviceId == "${device.deviceId}" then
                                    del(.encryptionPasswordFile) |
                                    .encryptionPassword = ''$${device.variableName}
                                  else
                                    .
                                  end
                                )
                              '')
                              devicesWithSecrets;
                            jqRawFiles = map (device: "--rawfile ${device.variableName} ${lib.escapeShellArg device.secretPath}") devicesWithSecrets;
                          in "${jq} ${lib.concatStringsSep " " jqRawFiles} ${lib.escapeShellArg (lib.concatStringsSep "|" (["."] ++ jqUpdates))}";
                        }.${
                          conf_type
                        };
                    in ''
                      ${injectSecretsJqCmd} ${jsonPreSecretsFile} | curl --json @- -X POST ${s.baseAddress}
                    ''
                  ))
                  (lib.concatStringsSep "\n")
                ]
                + lib.optionalString s.override ''
                  stale_${conf_type}_ids="$(curl -X GET ${s.baseAddress} | ${jq} \
                    --argjson new_ids ${lib.escapeShellArg (builtins.toJSON s.new_conf_IDs)} \
                    --raw-output \
                    '[.[].${s.GET_IdAttrName}] - $new_ids | .[]'
                  )"
                  for id in ''${stale_${conf_type}_ids}; do
                    >&2 echo "Deleting stale device: $id"
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
      options = {
        services.syncthing = {
          enable = mkEnableOption "Syncthing, a self-hosted open-source alternative to Dropbox and Bittorrent Sync";

          cert = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Path to the cert.pem file, which will be copied into Syncthing's configDir.";
          };

          key = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Path to the key.pem file, which will be copied into Syncthing's configDir.";
          };

          overrideDevices = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to delete the devices which are not configured via the devices option.";
          };

          overrideFolders = mkOption {
            type = types.bool;
            default = !anyAutoAccept;
            description = "Whether to delete the folders which are not configured via the folders option.";
          };

          settings = mkOption {
            type = types.submodule {
              freeformType = settingsFormat.type;
              options = {
                options = mkOption {
                  default = {};
                  description = "The options element contains all other global configuration options";
                  type = types.submodule {
                    freeformType = settingsFormat.type;
                    options = {
                      localAnnounceEnabled = mkOption {
                        type = types.nullOr types.bool;
                        default = null;
                        description = "Whether to send announcements to the local LAN.";
                      };
                      globalAnnounceEnabled = mkOption {
                        type = types.nullOr types.bool;
                        default = null;
                        description = "Whether to send announcements to the global discovery servers.";
                      };
                      relaysEnabled = mkOption {
                        type = types.nullOr types.bool;
                        default = null;
                        description = "When true, relays will be connected to and potentially used for device to device connections.";
                      };
                      urAccepted = mkOption {
                        type = types.nullOr types.int;
                        default = null;
                        description = "Whether the user has accepted to submit anonymous usage data.";
                      };
                    };
                  };
                };

                devices = mkOption {
                  default = {};
                  description = "Peers/devices which Syncthing should communicate with.";
                  type = types.attrsOf (types.submodule ({name, ...}: {
                    freeformType = settingsFormat.type;
                    options = {
                      name = mkOption {
                        type = types.str;
                        default = name;
                        description = "The name of the device.";
                      };
                      id = mkOption {
                        type = types.str;
                        description = "The device ID.";
                      };
                      autoAcceptFolders = mkOption {
                        type = types.bool;
                        default = false;
                        description = "Automatically create or share folders that this device advertises at the default path.";
                      };
                    };
                  }));
                };

                folders = mkOption {
                  default = {};
                  description = "Folders which should be shared by Syncthing.";
                  type = types.attrsOf (types.submodule ({name, ...}: {
                    freeformType = settingsFormat.type;
                    options = {
                      enable = mkOption {
                        type = types.bool;
                        default = true;
                        description = "Whether to share this folder.";
                      };
                      path = mkOption {
                        type = types.str;
                        default = name;
                        description = "The path to the folder which should be shared.";
                      };
                      id = mkOption {
                        type = types.str;
                        default = name;
                        description = "The ID of the folder. Must be the same on all devices.";
                      };
                      label = mkOption {
                        type = types.str;
                        default = name;
                        description = "The label of the folder.";
                      };
                      type = mkOption {
                        type = types.enum ["sendreceive" "sendonly" "receiveonly" "receiveencrypted"];
                        default = "sendreceive";
                        description = "Controls how the folder is handled by Syncthing.";
                      };
                      devices = mkOption {
                        type = types.listOf (types.oneOf [
                          types.str
                          (types.submodule {
                            freeformType = settingsFormat.type;
                            options = {
                              name = mkOption {
                                type = types.str;
                                description = "The name of a device defined in the devices option.";
                              };
                              encryptionPasswordFile = mkOption {
                                type = types.nullOr types.path;
                                default = null;
                                description = "Path to encryption password file.";
                              };
                            };
                          })
                        ]);
                        default = [];
                        description = "The devices this folder should be shared with.";
                      };
                    };
                  }));
                };
              };
            };
            default = {};
            description = "Extra configuration options for Syncthing.";
          };

          guiAddress = mkOption {
            type = types.str;
            default = "127.0.0.1:8384";
            description = "The address to serve the web interface at.";
          };

          user = mkOption {
            type = types.str;
            default = defaultUser;
            description = "The user to run Syncthing as.";
          };

          group = mkOption {
            type = types.str;
            default = defaultGroup;
            description = "The group to run Syncthing under.";
          };

          dataDir = mkOption {
            type = types.path;
            default = "/var/lib/syncthing";
            description = "The path where synchronised directories will exist.";
          };

          configDir = mkOption {
            type = types.path;
            default = cfg.dataDir + "/.config/syncthing";
            description = "The path where the settings and keys will exist.";
          };

          openDefaultPorts = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to open the default ports in the firewall (not applicable on Darwin).";
          };

          package = mkPackageOption pkgs "syncthing" {};
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = !(cfg.overrideFolders && anyAutoAccept);
            message = "services.syncthing.overrideFolders will delete auto-accepted folders from the configuration, creating path conflicts.";
          }
        ];

        environment.systemPackages = [cfg.package];

        launchd.user.agents.syncthing = {
          serviceConfig = {
            ProgramArguments = [
              "${cfg.package}/bin/syncthing"
              "-no-browser"
              "-gui-address=${
                if isUnixGui
                then "unix://"
                else ""
              }${cfg.guiAddress}"
              "-config=${cfg.configDir}"
              "-data=${cfg.configDir}"
            ];
            EnvironmentVariables = {
              STNORESTART = "yes";
              STNOUPGRADE = "yes";
            };
            KeepAlive = true;
            RunAtLoad = true;
            ProcessType = "Background";
            StandardOutPath = "${cfg.configDir}/syncthing.log";
            StandardErrorPath = "${cfg.configDir}/syncthing.log";
          };
        };

        launchd.user.agents.syncthing-init = mkIf (cleanedConfig != {}) {
          serviceConfig = {
            ProgramArguments = ["${updateConfig}"];
            RunAtLoad = true;
            KeepAlive = false;
            ProcessType = "Background";
            StandardOutPath = "${cfg.configDir}/syncthing-init.log";
            StandardErrorPath = "${cfg.configDir}/syncthing-init.log";
          };
        };

        system.activationScripts.syncthing = mkIf (cfg.cert != null || cfg.key != null) ''
          echo "Setting up Syncthing certificates..."
          mkdir -p ${cfg.configDir}
          ${optionalString (cfg.cert != null) ''
            cp ${toString cfg.cert} ${cfg.configDir}/cert.pem
            chmod 644 ${cfg.configDir}/cert.pem
          ''}
          ${optionalString (cfg.key != null) ''
            cp ${toString cfg.key} ${cfg.configDir}/key.pem
            chmod 600 ${cfg.configDir}/key.pem
          ''}
        '';
      };
    };
}
