{
	user,
	hostname,
	...
}: let
	secrets = import ../../lib/secrets.nix;
in {
	sops.secrets =
		secrets.mkSyncthingSecrets {
			inherit hostname user;
			isDarwin = false;
		}
		// {
			tahani-paperless-password = {
				sopsFile = ../../secrets/tahani-paperless-password;
				format = "binary";
			};
		};
}
