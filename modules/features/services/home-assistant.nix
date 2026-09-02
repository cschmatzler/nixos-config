_: {
  den.aspects.home-assistant.nixos = {
    config,
    pkgs,
    ...
  }: {
    networking.hosts."127.0.0.1" = ["core-mosquitto"];

    sops.secrets.zigbee2mqtt-environment = {
      format = "binary";
      sopsFile = ../../../secrets/zigbee2mqtt-environment;
      restartUnits = ["zigbee2mqtt.service"];
    };

    services = {
      mosquitto = {
        enable = true;
        listeners = [
          {
            address = "127.0.0.1";
            port = 1883;
            omitPasswordAuth = true;
            acl = ["pattern readwrite #"];
            settings.allow_anonymous = true;
          }
        ];
      };

      go2rtc = {
        enable = true;
        settings.api.listen = "127.0.0.1:1984";
      };

      zigbee2mqtt = {
        enable = true;
        settings = {
          version = 5;
          permit_join = false;
          mqtt.server = "mqtt://127.0.0.1:1883";
          serial = {
            port = "/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_76db1eb86012ef11848775b8bf9df066-if00-port0";
            adapter = "ember";
          };
          advanced = {
            channel = 11;
            pan_id = 50046;
            network_key = "MISSING_RESTORE_FROM_BACKUP";
          };
          frontend = {
            enabled = true;
            host = "127.0.0.1";
            port = 8099;
          };
          homeassistant.enabled = true;
        };
      };

      home-assistant = {
        enable = true;
        config = {
          api = {};
          assist_pipeline = {};
          cloud = {};
          conversation = {};
          dhcp = {};
          energy = {};
          file = {};
          go2rtc.url = "http://127.0.0.1:1984";
          history = {};
          homeassistant.time_zone = "Europe/Berlin";
          homeassistant_alerts = {};
          logbook = {};
          media_source = {};
          mobile_app = {};
          my = {};
          ssdp = {};
          stream = {};
          sun = {};
          usage_prediction = {};
          webhook = {};
          zeroconf = {};
          "automation ui" = "!include automations.yaml";
          "scene ui" = "!include scenes.yaml";
          "script ui" = "!include scripts.yaml";
          http = {
            server_host = ["0.0.0.0" "::"];
            server_port = 8123;
            use_x_forwarded_for = true;
            trusted_proxies = ["127.0.0.1" "::1"];
          };
        };

        extraComponents = [
          "apple_tv"
          "eheimdigital"
          "esphome"
          "go2rtc"
          "google_translate"
          "group"
          "home_connect"
          "isal"
          "mcp_server"
          "met"
          "mobile_app"
          "mqtt"
          "radio_browser"
          "samsungtv"
          "shopping_list"
          "sonos"
          "sun"
          "tessie"
          "thread"
        ];
        customComponents = with pkgs.home-assistant-custom-components; [
          better_thermostat
          scheduler
        ];
        customLovelaceModules = [
          (pkgs.callPackage ./_home-assistant-packages/scheduler-card.nix {})
          (pkgs.callPackage ./_home-assistant-packages/ha-floorplan.nix {})
          (pkgs.callPackage ./_home-assistant-packages/better-thermostat-ui-card.nix {})
        ];
      };
    };

    systemd = {
      tmpfiles.rules = [
        "f /var/lib/hass/automations.yaml 0600 hass hass -"
        "f /var/lib/hass/scenes.yaml 0600 hass hass -"
        "f /var/lib/hass/scripts.yaml 0600 hass hass -"
      ];

      services = {
        zigbee2mqtt = {
          requires = ["mosquitto.service"];
          after = ["mosquitto.service"];
          serviceConfig.EnvironmentFile = config.sops.secrets.zigbee2mqtt-environment.path;
        };

        home-assistant = {
          wants = ["go2rtc.service" "mosquitto.service" "zigbee2mqtt.service"];
          after = ["go2rtc.service" "mosquitto.service" "zigbee2mqtt.service"];
        };

        home-assistant-tailscale = import ../../_lib/tailscale-serve.nix {
          inherit pkgs;
          identity = "svc:ha";
          port = 8123;
          after = ["home-assistant.service"];
        };
      };
    };
  };
}
