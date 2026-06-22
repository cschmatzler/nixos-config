{
	pkgs,
	nvim-plugin-sources,
	...
}: let
	neojj =
		pkgs.vimUtils.buildVimPlugin {
			pname = "neojj";
			version = "unstable";
			src = nvim-plugin-sources.neojj;
			doCheck = false;
		};

	jj-diffconflicts =
		pkgs.vimUtils.buildVimPlugin {
			pname = "jj-diffconflicts";
			version = "unstable";
			src =
				pkgs.fetchFromGitHub {
					owner = "rafikdraoui";
					repo = "jj-diffconflicts";
					rev = "main";
					hash = "sha256-MjacjGlBRwActBBGeBZDHz8jz5J3Mt6KoDsf8WKgUDA=";
				};
			doCheck = false;
		};
in {
	programs.nixvim = {
		extraPlugins = with pkgs.vimPlugins; [
			neojj
			jj-diffconflicts
			plenary-nvim
		];

		extraConfigLua = ''
			local function open_difftastic_from_neojj(revset)
				-- Neojj invokes diff integrations from plenary.async callbacks in some
				-- paths. Defer until Neovim is back on the main loop. Also force a Lua
				-- GC cycle before calling difftastic.nvim: mlua keeps Lua references on
				-- an auxiliary stack, and repeated opens can exhaust it even for tiny diffs.
				vim.defer_fn(function()
					collectgarbage("collect")

					local ok, err = pcall(require("difftastic-nvim").open, revset)
					if not ok then
						vim.notify("difftastic-nvim: " .. tostring(err), vim.log.levels.ERROR)
					end
				end, 50)
			end

			package.loaded["neojj.integrations.diffview"] = {
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
					if section_name == "worktree" or section_name == "conflict" then
						revset = "@"
					elseif section_name == "range" and item_name then
						revset = item_name
					elseif (section_name == "stashes" or section_name == "commit") and item_name then
						revset = item_name
					elseif (section_name == "recent" or section_name == "log" or section_name == "bookmarks" or (section_name and section_name:match("unmerged$"))) and item_name then
						if type(item_name) == "table" then
							revset = string.format("%s..%s", item_name[1], item_name[#item_name])
						else
							revset = item_name:match("[a-zA-Z0-9]+") or item_name
						end
					elseif section_name == nil and item_name ~= nil then
						revset = item_name
					end

					open_difftastic_from_neojj(revset)
				end,
			}

			require("neojj").setup({
				kind = "replace",
				commit_popup = {
					kind = "floating",
				},
				preview_buffer = {
					kind = "floating",
				},
				popup = {
					kind = "floating",
				},
				integrations = {
					diffview = false,
					codediff = false,
					snacks = true,
				},
				sections = {
					files = {
						folded = false,
						hidden = false,
					},
					conflicts = {
						folded = false,
						hidden = false,
					},
					untracked = {
						folded = false,
						hidden = false,
					},
					bookmarks = {
						folded = true,
						hidden = false,
						show_deleted = true,
						show_remote = true,
					},
					recent = {
						folded = true,
						hidden = false,
					},
				},
			})

			local neojj_config = require("neojj.config")
			neojj_config.get_diff_viewer = function()
				return "diffview"
			end
		'';
	};
}
