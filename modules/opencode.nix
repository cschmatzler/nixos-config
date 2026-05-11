{lib, ...}: let
	local = import ./_lib/local.nix;
	inherit (local) secretPath;
	secretLib = import ./_lib/secrets.nix {inherit lib;};
	opencodeSecretPath = secretPath "opencode-api-key";
in {
	den.aspects.opencode-api-key.os = {
		sops.secrets.opencode-api-key =
			secretLib.mkUserBinarySecret {
				name = "opencode-api-key";
				sopsFile = ../secrets/opencode-api-key;
			};
	};

	den.aspects.opencode.homeManager = {lib, ...}: {
		programs.nushell.extraEnv =
			lib.mkAfter ''
				if ("${opencodeSecretPath}" | path exists) {
					$env.OPENCODE_API_KEY = (open --raw "${opencodeSecretPath}" | str trim)
				}
			'';
	};
}
