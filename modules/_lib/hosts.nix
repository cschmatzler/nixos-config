{
	den,
	lib,
}: {
	mkUserHost = {
		system,
		host,
		user,
		userAspect ? "${host}-${user}",
		includes ? [],
		homeManager ? null,
	}:
		(lib.setAttrByPath ["den" "hosts" system host "users" user "aspect"] userAspect)
		// (lib.setAttrByPath ["den" "aspects" userAspect] ({inherit includes;}
				// lib.optionalAttrs (homeManager != null) {
					inherit homeManager;
				}));

	mkPerHostAspect = {
		host,
		includes ? [],
		darwin ? null,
		nixos ? null,
	}:
		lib.setAttrByPath ["den" "aspects" host "includes"] [
			(den.lib.perHost ({inherit includes;}
					// lib.optionalAttrs (darwin != null) {
						inherit darwin;
					}
					// lib.optionalAttrs (nixos != null) {
						inherit nixos;
					}))
		];
}
