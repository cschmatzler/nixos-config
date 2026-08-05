{lib}: {
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
  folders = lib.mapAttrsToList (folderId: folder:
    folder
    // {
      id = folderId;
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
                jsonPreSecretsFile = pkgs.writeTextFile {
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
  )
