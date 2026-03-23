{den, ...}: {
	den.aspects.host-public-server.includes = [
		den.aspects.host-nixos-base
		den.aspects.fail2ban
	];
}
