{den, ...}: {
	den.aspects.host-nixos-base.includes = [
		den.aspects.nixos-system
		den.aspects.core
		den.aspects.mosh
		den.aspects.openssh
		den.aspects.tailscale
	];
}
