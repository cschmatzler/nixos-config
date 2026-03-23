{den, ...}: {
	den.aspects.host-darwin-base.includes = [
		den.aspects.darwin-system
		den.aspects.core
		den.aspects.tailscale
	];
}
