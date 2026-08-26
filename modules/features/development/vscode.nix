_: {
  den.aspects = {
    vscode = {
      darwin = {pkgs, ...}: {
        environment.systemPackages = [pkgs.vscode];

        # Keep Vim motions repeatable when a key is held down.
        system.defaults.CustomUserPreferences."com.microsoft.VSCode".ApplePressAndHoldEnabled = false;
      };

      homeManager = _: {
        imports = [
          ./_vscode/default.nix
        ];
      };
    };

    vscode-remote.nixos = {pkgs, ...}: {
      # The VS Code server ships dynamically linked binaries. nix-ld provides
      # their expected loader on NixOS.
      programs.nix-ld.enable = true;

      # VS Code Remote SSH uses these while installing and updating its server.
      environment.systemPackages = with pkgs; [
        bash
        curl
        gnutar
        gzip
      ];
    };

    vscode-remote.homeManager = {pkgs, ...}: let
      jsonFormat = pkgs.formats.json {};
    in {
      # Remote extensions read machine settings from the VS Code server, not
      # from the desktop client's settings file.
      home.file.".vscode-server/data/Machine/settings.json".source = jsonFormat.generate "vscode-remote-settings" (
        (import ./_vscode/tool-settings.nix {inherit pkgs;})
        // {
          "terminal.integrated.profiles.linux".fish.path = "${pkgs.fish}/bin/fish";
          "terminal.integrated.defaultProfile.linux" = "fish";
        }
      );
    };
  };
}
