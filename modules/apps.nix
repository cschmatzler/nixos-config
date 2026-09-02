_: {
  perSystem = {pkgs, ...}: {
    formatter = pkgs.alejandra;

    apps = {
      apply.program = pkgs.writeShellScriptBin "apply" ''
        case "$(uname -s)" in
          Darwin) exec sudo darwin-rebuild switch --flake . "$@" ;;
          Linux) exec sudo nixos-rebuild switch --flake . "$@" ;;
        esac
      '';
      update.program = pkgs.writeShellScriptBin "update" ''
        nix flake update "$@"
        nix run .#write-flake
      '';
    };
  };
}
