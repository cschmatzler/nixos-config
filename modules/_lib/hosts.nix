{
	den,
	lib,
}: let
	merge = lib.recursiveUpdate;
in {
	mkUserHost = {
		system,
		host,
		user,
		userAspect ? "${host}-${user}",
		includes ? [],
		homeManager ? null,
	}:
		merge
		(lib.setAttrByPath ["den" "hosts" system host "users" user "aspect"] den.aspects.${userAspect})
		(lib.setAttrByPath ["den" "aspects" userAspect] ({inherit includes;}
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
