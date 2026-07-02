{
  pkgs,
  nvim-plugin-sources,
  ...
}: let
  diffs-nvim = pkgs.vimUtils.buildVimPlugin {
    pname = "diffs-nvim";
    version = "unstable";
    src = nvim-plugin-sources.diffs-nvim;
    doCheck = false;
  };
in {
  programs.nixvim = {
    extraPlugins = [
      diffs-nvim
    ];

    extraConfigLuaPre = ''
      vim.g.diffs = {
        integrations = {
          neogit = true,
        },
      }
    '';
  };
}
