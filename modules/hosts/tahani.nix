{den, ...}: let
  local = import ../_lib/local.nix;
in {
  den.aspects.tahani = {
    includes = [
      den.aspects.host-nixos-base
      den.aspects.home-assistant
      den.aspects.email
      den.aspects.syncthing
      den.aspects.plannotator
      den.aspects.vscode-remote
    ];

    provides.to-users = {
      includes = [
        den.aspects.user-workstation
        den.aspects.user-personal
        den.aspects.email
        den.aspects.vscode-remote
      ];
      homeManager.home.stateVersion = "25.11";
    };

    nixos = {pkgs, ...}: {
      system.stateVersion = "25.11";
      networking.hostName = "tahani";

      boot = {
        loader = {
          systemd-boot = {
            enable = true;
            configurationLimit = 42;
          };
          efi.canTouchEfiVariables = true;
        };
        initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
        kernelPackages = pkgs.linuxPackages;
      };

      fileSystems."/" = {
        device = "/dev/disk/by-label/NIXROOT";
        fsType = "ext4";
      };
      fileSystems."/boot" = {
        device = "/dev/disk/by-label/NIXBOOT";
        fsType = "vfat";
      };
      swapDevices = [
        {
          device = "/swapfile";
          size = 16 * 1024;
        }
      ];

      networking = {
        useDHCP = false;
        interfaces.eno1.ipv4.addresses = [
          {
            address = "192.168.1.10";
            prefixLength = 24;
          }
        ];
        defaultGateway = "192.168.1.1";
        nameservers = ["1.1.1.1"];
        firewall = {
          enable = true;
          trustedInterfaces = ["eno1" "tailscale0" "docker0"];
          allowedTCPPorts = [22];
          checkReversePath = "loose";
        };
      };
      services.tailscale.extraSetFlags = ["--accept-routes=false"];

      environment.systemPackages = [pkgs._1password-cli];
      virtualisation.docker.enable = true;
      users.users.${local.user.name}.extraGroups = ["docker"];

      # Executor (self-hosted), exposed as https://executor.<tailnet>
      virtualisation.oci-containers = {
        backend = "docker";
        containers.executor = {
          image = "ghcr.io/usefulsoftwareco/executor-selfhost:1.6.7";
          pull = "always";
          ports = ["127.0.0.1:4788:4788"];
          volumes = ["/var/lib/executor:/data"];
          user = "65532:65532";
          capabilities.ALL = false;
          environment = {
            EXECUTOR_ALLOW_LOCAL_NETWORK = "false";
            EXECUTOR_WEB_BASE_URL = "https://${local.tailscaleHost "executor"}";
            HOME = "/tmp";
            TMPDIR = "/tmp";
          };
          extraOptions = [
            # The upstream distroless image's shell-form health check cannot run.
            "--no-healthcheck"
            "--read-only"
            "--security-opt=no-new-privileges=true"
            "--tmpfs=/tmp:rw,nosuid,nodev,noexec,size=64m,mode=1777"
            "--cpus=4"
            "--memory=2g"
            "--memory-swap=2g"
            "--pids-limit=256"
          ];
        };
      };
      systemd = {
        # 65532 is the distroless image's nonroot UID/GID.
        tmpfiles.rules = ["d /var/lib/executor 0700 65532 65532 -"];
        services.docker-executor.serviceConfig.ExecStartPost = "${pkgs.curl}/bin/curl --fail --silent --show-error --connect-timeout 2 --max-time 5 --retry 12 --retry-delay 5 --retry-max-time 60 --retry-connrefused --retry-all-errors http://127.0.0.1:4788/api/health";
        services.executor-tailscale = import ../_lib/tailscale-serve.nix {
          inherit pkgs;
          identity = "svc:executor";
          port = 4788;
          after = ["docker-executor.service"];
        };
      };
    };
  };
}
