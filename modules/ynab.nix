_: let
  local = import ./_lib/local.nix;
  inherit (local) secretPath;
  secretLib = import ./_lib/secrets.nix {};
  ynabSecretPath = secretPath "ynab-api-key";
in {
  den.aspects.ynab = {
    os.sops.secrets.ynab-api-key = secretLib.mkUserBinarySecret {
      name = "ynab-api-key";
      sopsFile = ../secrets/ynab-api-key;
    };

    homeManager = {lib, ...}: {
      programs.fish.shellInit = lib.mkAfter ''
        if test -f "${ynabSecretPath}"
          set -gx YNAB_API_KEY (string trim -- (cat "${ynabSecretPath}"))
        end
      '';
    };
  };
}
