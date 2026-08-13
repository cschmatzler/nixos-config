_: {
  den.aspects.ynab = {
    os.sops.secrets.ynab-api-key = (import ../../_lib/secrets.nix {}).mkUserBinarySecret {
      name = "ynab-api-key";
      sopsFile = ../../../secrets/ynab-api-key;
    };

    homeManager = {lib, ...}: {
      programs.fish.shellInit = lib.mkAfter ''
        if test -f "${(import ../../_lib/local.nix).secretPath "ynab-api-key"}"
          set -gx YNAB_API_KEY (string trim -- (cat "${(import ../../_lib/local.nix).secretPath "ynab-api-key"}"))
        end
      '';
    };
  };
}
