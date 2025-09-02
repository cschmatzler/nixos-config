{
  lib,
  pkgs,
  ...
}: {
  programs.nixvim.plugins = {
    lsp = {
      enable = true;
      inlayHints = true;
      servers = {
        nil_ls.enable = true;
        vtsls = {
          enable = true;
          package = pkgs.vtsls;
          filetypes = ["vue" "javascript" "javascriptreact" "typescript" "typescriptreact"];
          settings = {
            vtsls = {
              tsserver = {
                globalPlugins = [
                  {
                    name = "@vue/typescript-plugin";
                    # Keep your working path to the language server package
                    location = "${pkgs.vue-language-server}/lib/language-tools/packages/language-server";
                    languages = ["vue"];
                    configNamespace = "typescript";
                    enableForWorkspaceTypeScriptVersions = true;
                  }
                ];
              };
            };
          };
        };
        cssls.enable = true;
        dockerls.enable = true;
        elixirls.enable = true;
        yamlls.enable = true;
      };
    };
  };
}
