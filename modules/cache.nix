{...}: let
	caddyLib = import ./_lib/caddy.nix;
in {
	den.aspects.cache.nixos = {
		services.caddy.virtualHosts =
			caddyLib.mkTailscaleVHost {
				name = "cache";
				configText = "reverse_proxy localhost:32843";
			};
	};
}
