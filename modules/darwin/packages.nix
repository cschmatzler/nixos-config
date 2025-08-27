{pkgs}:
with pkgs; [
  _1password-gui
  dockutil
  xcodes
  mas
  raycast
  # whatsapp-for-mac
  (callPackage ../bin/open-project.nix {})
]
