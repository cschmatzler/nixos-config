{
  user = "cschmatzler";

  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHfRZQ+7ejD3YHbyMTrV0gN1Gc0DxtGgl5CVZSupo5ws"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/I+/2QT47raegzMIyhwMEPKarJP/+Ox9ewA4ZFJwk/"
  ];

  stateVersions = {
    darwin = 6;
    nixos = "25.11";
    homeManager = "25.11";
  };
}
