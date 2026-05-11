{lib, ...}: let
	local = import ./_lib/local.nix;
	inherit (local) secretPath;
	secretLib = import ./_lib/secrets.nix {inherit lib;};
	ynabSecretPath = secretPath "ynab-api-key";
in {
	den.aspects.ynab-api-key.os = {
		sops.secrets.ynab-api-key =
			secretLib.mkUserBinarySecret {
				name = "ynab-api-key";
				sopsFile = ../secrets/ynab-api-key;
			};
	};

	den.aspects.ynab.homeManager = {lib, ...}: {
		programs.nushell.extraEnv =
			lib.mkAfter ''
				if ("${ynabSecretPath}" | path exists) {
					$env.YNAB_API_KEY = (open --raw "${ynabSecretPath}" | str trim)
				}
			'';
	};
}
