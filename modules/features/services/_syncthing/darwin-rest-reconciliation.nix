{lib}: {
  pkgs,
  configDir,
  guiAddress,
  desiredState,
}: let
  cleanedConfig = lib.converge (lib.filterAttrsRecursive (_: value: value != null && value != {})) desiredState;
  isUnixGui = (builtins.substring 0 1 guiAddress) == "/";
  socketArgs = lib.optionalString isUnixGui "--unix-socket ${lib.escapeShellArg guiAddress}";
  address = path:
    if isUnixGui
    then "http://.${path}"
    else "http://${guiAddress}${path}";
  requestArgs = path: "${socketArgs} ${lib.escapeShellArg (address path)}";
  devices = lib.mapAttrsToList (_: device: device // {deviceID = device.id;}) desiredState.devices;
  folders = lib.mapAttrsToList (folderId: folder:
    folder
    // {
      id = folderId;
      devices =
        map (
          device:
            if builtins.isString device
            then {deviceId = desiredState.devices.${device}.id;}
            else if builtins.isAttrs device
            then {deviceId = desiredState.devices.${device.name}.id;} // device
            else throw "Invalid type for devices in Syncthing folder; expected string or attrset."
        )
        folder.devices;
    })
  desiredState.folders;
  jq = "${pkgs.jq}/bin/jq";

  mkUpserts = {
    label,
    endpoint,
    values,
  }:
    lib.concatMapStringsSep "\n" (value: ''
      echo "Upserting Syncthing ${label}: ${value.id}"
      ${jq} . ${pkgs.writeText "syncthing-${label}-${value.id}.json" (builtins.toJSON value)} | syncthing_request --json @- -X POST ${requestArgs endpoint}
    '')
    values;

  mkDeletes = {
    label,
    endpoint,
    idAttribute,
    desiredIds,
  }: ''
    current_ids="$(syncthing_request -X GET ${requestArgs endpoint} | ${jq} \
      --argjson desired_ids ${lib.escapeShellArg (builtins.toJSON desiredIds)} \
      --raw-output \
      '[.[].${idAttribute}] - $desired_ids | .[]'
    )"
    base_url=${lib.escapeShellArg (address endpoint)}
    while IFS= read -r id; do
      if [ -z "$id" ]; then
        continue
      fi
      encoded_id="$(printf '%s' "$id" | ${jq} -sRr '@uri')"
      echo "Deleting undeclared Syncthing ${label}: $id"
      syncthing_request -X DELETE ${socketArgs} "$base_url/$encoded_id"
    done < <(printf '%s\n' "$current_ids")
  '';

  optionNames = lib.subtractLists ["folders" "devices"] (builtins.attrNames cleanedConfig);
  applyOptions =
    lib.concatMapStringsSep "\n" (optionName: ''
      echo "Applying Syncthing options: ${optionName}"
      syncthing_request -X PUT --json ${lib.escapeShellArg (builtins.toJSON cleanedConfig.${optionName})} ${requestArgs "/rest/config/${optionName}"}
    '')
    optionNames;
in
  pkgs.writers.writeBash "reconcile-syncthing-desired-state" ''
    set -euo pipefail
    umask 0077

    config_file=${lib.escapeShellArg "${configDir}/config.xml"}
    temp_dir="$(${pkgs.coreutils}/bin/mktemp -d)"
    trap '${pkgs.coreutils}/bin/rm -rf "$temp_dir"' EXIT HUP INT TERM
    deadline=$((SECONDS + 60))

    readiness_failure() {
      echo "Syncthing credentials and local endpoint were not ready within 60 seconds" >&2
      exit 1
    }

    readiness_pause() {
      if [ $((deadline - SECONDS)) -le 1 ]; then
        readiness_failure
      fi
      ${pkgs.coreutils}/bin/sleep 1
    }

    echo "Waiting for Syncthing credentials"
    while ! ${pkgs.libxml2}/bin/xmllint \
      --xpath 'string(configuration/gui/apikey)' \
      "$config_file" \
      >"$temp_dir/api-key" 2>/dev/null; do
      if [ "$SECONDS" -ge "$deadline" ]; then
        readiness_failure
      fi
      readiness_pause
    done
    if [ "$SECONDS" -ge "$deadline" ]; then
      readiness_failure
    fi
    (printf 'X-API-Key: '; ${pkgs.coreutils}/bin/cat "$temp_dir/api-key") >"$temp_dir/headers"

    syncthing_request() {
      ${pkgs.curl}/bin/curl \
        --fail-with-body \
        --silent \
        --show-error \
        --insecure \
        --header "@$temp_dir/headers" \
        --connect-timeout 1 \
        --max-time 5 \
        "$@"
    }

    echo "Waiting for the Syncthing local endpoint"
    while true; do
      remaining_seconds=$((deadline - SECONDS))
      if [ "$remaining_seconds" -le 0 ]; then
        readiness_failure
      fi

      probe_timeout=5
      if [ "$remaining_seconds" -lt "$probe_timeout" ]; then
        probe_timeout="$remaining_seconds"
      fi

      if syncthing_request --max-time "$probe_timeout" ${requestArgs "/rest/noauth/health"} >/dev/null; then
        if [ "$SECONDS" -ge "$deadline" ]; then
          readiness_failure
        fi
        break
      fi
      readiness_pause
    done

    echo "Reconciling declared Syncthing devices"
    ${mkUpserts {
      label = "device";
      endpoint = "/rest/config/devices";
      values = devices;
    }}

    echo "Reconciling declared Syncthing folders"
    ${mkUpserts {
      label = "folder";
      endpoint = "/rest/config/folders";
      values = folders;
    }}

    echo "Reconciling declared Syncthing options"
    ${applyOptions}

    echo "Deleting undeclared Syncthing folders"
    ${mkDeletes {
      label = "folder";
      endpoint = "/rest/config/folders";
      idAttribute = "id";
      desiredIds = map (folder: folder.id) folders;
    }}

    echo "Deleting undeclared Syncthing devices"
    ${mkDeletes {
      label = "device";
      endpoint = "/rest/config/devices";
      idAttribute = "deviceID";
      desiredIds = map (device: device.id) devices;
    }}

    restart_state="$(syncthing_request ${requestArgs "/rest/config/restart-required"})"
    if printf '%s' "$restart_state" | ${jq} -e '.requiresRestart == true' >/dev/null; then
      echo "Restarting Syncthing after desired-state reconciliation"
      syncthing_request -X POST ${requestArgs "/rest/system/restart"}
    fi
  ''
