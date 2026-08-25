{
  pkgs,
  nvim-plugin-sources,
  ...
}: {
  programs.nixvim = {
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
        pname = "code-review-nvim";
        version = "unstable";
        src = nvim-plugin-sources.code-review-nvim;
        doCheck = false;
      })
    ];
    extraConfigLua = ''
      require('code-review').setup({
        keymaps = false,
        comment = {
          storage = {
            backend = "file",
          },
        },
        ui = {
          input_window = {
            title = "Review",
            height = 4,
            border = "single",
          },
          preview = {
            float = {
              border = "single",
            },
          },
        },
      })
    '';
  };
}
