{
	programs.nixvim.plugins = {
		lsp = {
			enable = true;
			inlayHints = true;
			servers = {
				copilot = {
					enable = true;
					package = null;
					cmd = ["copilot-language-server" "--stdio"];
				};
				cssls.enable = true;
				dockerls.enable = true;
				jsonls.enable = true;
				nil_ls.enable = true;
				vtsls.enable = true;
				yamlls.enable = true;
				zk.enable = true;
			};
		};
	};
}
