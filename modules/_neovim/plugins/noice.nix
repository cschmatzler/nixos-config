{...}: {
	programs.nixvim.plugins.noice = {
		enable = true;
		settings = {
			cmdline = {
				enabled = true;
				view = "cmdline_popup";
			};
			messages = {
				enabled = true;
				view = "mini";
				view_error = "mini";
				view_warn = "mini";
				view_history = "split";
				view_search = "virtualtext";
			};
			notify.enabled = false;
			popupmenu = {
				enabled = true;
				backend = "nui";
			};
			lsp = {
				progress = {
					enabled = true;
					view = "mini";
				};
				override = {
					"vim.lsp.util.convert_input_to_markdown_lines" = true;
					"vim.lsp.util.stylize_markdown" = true;
					"cmp.entry.get_documentation" = true;
				};
			};
			presets = {
				bottom_search = true;
				command_palette = true;
				long_message_to_split = true;
				lsp_doc_border = true;
			};
			views = {
				cmdline_popup.border = {
					style = "single";
					padding = [0 1];
				};
				popup.border = {
					style = "single";
					padding = [0 1];
				};
			};
		};
	};
}
