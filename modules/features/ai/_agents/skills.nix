{
  inputs,
  lib,
}: let
  skillDirs = path:
    lib.mapAttrs (name: _: path + "/${name}")
    (lib.filterAttrs (_: type: type == "directory") (builtins.readDir path));
in
  skillDirs ./skills
  // {
    bro = inputs.dmmulroy-skills + "/bro";
    show-me = inputs.humanlayer-skills + "/plugins/show-me/skills/show-me";
    visual-pr = inputs.humanlayer-skills + "/plugins/visual-pr/skills/visual-pr";
  }
