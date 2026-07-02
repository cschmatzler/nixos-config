{lib, ...}: let
  local = import ./_lib/local.nix;
  inherit (local) secretPath;
  secretLib = import ./_lib/secrets.nix {inherit lib;};
  apiKeyPath = secretPath "opencode-api-key";
in {
  den.aspects.ai-api-key.os = {
    sops.secrets.opencode-api-key = secretLib.mkUserBinarySecret {
      name = "opencode-api-key";
      sopsFile = ../secrets/opencode-api-key;
    };
  };

  den.aspects.ai-api-key.homeManager = {lib, ...}: {
    programs.fish.shellInit = lib.mkAfter ''
      if test -f "${apiKeyPath}"
        set -gx OPENCODE_API_KEY (string trim -- (cat "${apiKeyPath}"))
      end
    '';
  };
}
