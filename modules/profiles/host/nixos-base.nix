{den, ...}: {
	den.aspects.host-nixos-base.includes = [
		den.aspects.nixos-system
		den.aspects.core
		den.aspects.openssh
		den.aspects.tailscale
	];
}
