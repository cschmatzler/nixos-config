let
	local = import ./local.nix;
in {
	inherit (local) tailscaleHost;

	mkTailscaleVHost = {
		name,
		configText,
	}: {
		"${local.tailscaleHost name}" = {
			extraConfig = ''
				tls {
					get_certificate tailscale
				}
				${configText}
			'';
		};
	};
}
