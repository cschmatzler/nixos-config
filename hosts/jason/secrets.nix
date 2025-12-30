{user, ...}: {
	sops.age.keyFile = "/Users/${user}/.config/sops/age/keys.txt";
	sops.age.sshKeyPaths = [];
	sops.gnupg.sshKeyPaths = [];
}
