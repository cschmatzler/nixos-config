{lib, ...}: let
	local = import ./_lib/local.nix;
	inherit (local) secretPath;
	secretLib = import ./_lib/secrets.nix {inherit lib;};
	apiKeyPath = secretPath "opencode-api-key";
in {
	den.aspects.ai-api-key.os = {
		sops.secrets.opencode-api-key =
			secretLib.mkUserBinarySecret {
				name = "opencode-api-key";
				sopsFile = ../secrets/opencode-api-key;
			};
	};

	den.aspects.ai-api-key.homeManager = {lib, ...}: {
		programs.nushell.extraEnv =
			lib.mkAfter ''
				if ("${apiKeyPath}" | path exists) {
					$env.OPENCODE_API_KEY = (open --raw "${apiKeyPath}" | str trim)
				}
			'';
	};
}
