{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = [
      pkgs.vimPlugins.codediff-nvim
    ];

    extraConfigLua = ''
      require("codediff").setup({
        highlights = {
          line_insert = "DiffAdd",
          line_delete = "DiffDelete",
          char_insert = "CodeDiffCharInsertTheme",
          char_delete = "CodeDiffCharDeleteTheme",
        },
        diff = {
          layout = "inline",
          filler_text = "",
          compact = true,
          compact_context_lines = 3,
        },
      })
    '';
  };
}
