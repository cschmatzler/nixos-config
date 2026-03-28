{den, ...}: {
	den.aspects.user-base.includes = [
		den.aspects.shell
		den.aspects.ssh-client
		den.aspects.terminal
		den.aspects.atuin
		den.aspects.secrets
		den.aspects.zellij
		den.aspects.zk
	];
}
