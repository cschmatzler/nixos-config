{pkgs}:
with pkgs; [
  _1password-gui
  dockutil
  mas
  raycast
  whatsapp-for-mac
  (callPackage ../bin/open-project.nix {})
]
