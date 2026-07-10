{inputs, ...}: let
  local = import ./_lib/local.nix;
in {
  flake-file.inputs.sops-nix = {
    url = "github:Mic92/sops-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.default = {
    nixos = {
      imports = [inputs.sops-nix.nixosModules.sops];
      sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    };

    darwin = {
      imports = [inputs.sops-nix.darwinModules.sops];
      sops = {
        age.keyFile = "/Users/${local.user.name}/.config/sops/age/keys.txt";
        age.sshKeyPaths = [];
        gnupg.sshKeyPaths = [];
      };
    };
  };

  # Encryption/secrets tools
  den.aspects.secrets.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      age
      gnupg
      sops
      ssh-to-age
    ];
    home.sessionVariables.SOPS_AGE_SSH_PRIVATE_KEY_FILE = "~/.ssh/id_ed25519";
  };
}
