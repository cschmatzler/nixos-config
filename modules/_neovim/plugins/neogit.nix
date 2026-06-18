{
	programs.nixvim = {
		extraConfigLua = ''
			local neogit_config = require("neogit.config")
			neogit_config.get_diff_viewer = function()
				return "diffview"
			end

			package.loaded["neogit.integrations.diffview"] = {
				open = function(section_name, item_name, opts)
					opts = opts or {}

					if opts.on_close then
						vim.api.nvim_create_autocmd({ "BufEnter" }, {
							buffer = opts.on_close.handle,
							once = true,
							callback = opts.on_close.fn,
						})
					end

					local revset = nil
					if section_name == "staged" then
						revset = "--staged"
					elseif section_name == "worktree" or section_name == "merge" or section_name == "conflict" then
						revset = "HEAD"
					elseif section_name == "range" and item_name then
						revset = item_name
					elseif (section_name == "stashes" or section_name == "commit") and item_name then
						revset = item_name .. "^!"
					elseif (section_name == "recent" or section_name == "log" or (section_name and section_name:match("unmerged$"))) and item_name then
						if type(item_name) == "table" then
							revset = string.format("%s..%s", item_name[1], item_name[#item_name])
						else
							local commit = item_name:match("[a-f0-9]+") or item_name
							revset = commit .. "^!"
						end
					elseif section_name == nil and item_name ~= nil then
						revset = item_name .. "^!"
					end

					local difftastic = require("difftastic-nvim")
					difftastic.open(revset)

					if type(item_name) == "string" then
						vim.schedule(function()
							for idx, file in ipairs(difftastic.state.files or {}) do
								if file.path == item_name then
									difftastic.show_file(idx)
									break
								end
							end
						end)
					end
				end,
			}
		'';

		plugins.neogit = {
			enable = true;
			settings = {
				kind = "replace";
				commit_popup.kind = "floating";
				preview_buffer.kind = "floating";
				popup.kind = "floating";
				disable_commit_confirmation = true;
				integrations.diffview = false;
				sections = {
					untracked = {
						folded = false;
						hidden = false;
					};
					unstaged = {
						folded = false;
						hidden = false;
					};
					staged = {
						folded = false;
						hidden = false;
					};
					stashes = {
						folded = false;
						hidden = false;
					};
					unpulled = {
						folded = false;
						hidden = false;
					};
					unmerged = {
						folded = true;
						hidden = false;
					};
					recent = {
						folded = true;
						hidden = false;
					};
				};
			};
		};
	};
}
