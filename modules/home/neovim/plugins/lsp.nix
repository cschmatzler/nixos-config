{
	programs.nixvim.plugins = {
		lsp = {
			enable = true;
			inlayHints = true;
			servers = {
				nil_ls.enable = true;
				cssls.enable = true;
				dockerls.enable = true;
				yamlls.enable = true;
				vtsls.enable = true;
			};
		};
	};
}
