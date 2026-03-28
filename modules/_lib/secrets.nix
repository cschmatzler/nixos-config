{lib}: let
	local = import ./local.nix;
in rec {
	mkBinarySecret = {
		name,
		sopsFile,
		owner ? null,
		group ? null,
		path ? local.secretPath name,
	}:
		{
			inherit path sopsFile;
			format = "binary";
		}
		// lib.optionalAttrs (owner != null) {
			inherit owner;
		}
		// lib.optionalAttrs (group != null) {
			inherit group;
		};

	mkUserBinarySecret = {
		name,
		sopsFile,
		owner ? local.user.name,
		path ? local.secretPath name,
	}:
		mkBinarySecret {
			inherit name owner path sopsFile;
		};

	mkServiceBinarySecret = {
		name,
		sopsFile,
		serviceUser,
		serviceGroup ? serviceUser,
		path ? local.secretPath name,
	}:
		mkBinarySecret {
			inherit name path sopsFile;
			group = serviceGroup;
			owner = serviceUser;
		};
}
