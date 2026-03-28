{lib, ...}: let
	local = import ./_lib/local.nix;
in
	lib.foldl' lib.recursiveUpdate {} (
		lib.mapAttrsToList (
			host: hostMeta:
				lib.setAttrByPath ["den" "hosts" hostMeta.system host "users" local.user.name] {}
		)
		local.hosts
	)
