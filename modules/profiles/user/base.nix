{den, ...}: {
  den.aspects.user-base.includes = [
    den.aspects.secrets
    den.aspects.shell
    den.aspects.ssh-client
  ];
}
