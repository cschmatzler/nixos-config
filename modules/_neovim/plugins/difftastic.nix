{
	pkgs,
	nvim-plugin-sources,
	...
}: let
	difftastic-nvim-lib =
		pkgs.rustPlatform.buildRustPackage {
			pname = "difftastic-nvim-lib";
			version = "unstable";
			src = nvim-plugin-sources.difftastic-nvim;
			patches = [
				../patches/difftastic-nvim-mlua-aux-stack.patch
			];
			cargoLock.lockFile = "${nvim-plugin-sources.difftastic-nvim}/Cargo.lock";
			doCheck = false;
			installPhase = ''
				runHook preInstall
				mkdir -p $out/lib
				find target -path '*/release/libdifftastic_nvim.*' -type f -exec cp {} $out/lib/ \;
				runHook postInstall
			'';
		};

	difftastic-nvim =
		pkgs.vimUtils.buildVimPlugin {
			pname = "difftastic-nvim";
			version = "unstable";
			src = nvim-plugin-sources.difftastic-nvim;
			doCheck = false;
			postInstall = ''
				mkdir -p $out/target/release
				cp ${difftastic-nvim-lib}/lib/libdifftastic_nvim.* $out/target/release/
				cp ${difftastic-nvim-lib}/lib/libdifftastic_nvim.so $out/target/release/difftastic_nvim.so
			'';
		};
in {
	programs.nixvim = {
		extraPlugins = with pkgs.vimPlugins; [
			difftastic-nvim
			nui-nvim
		];

		extraPackages = [
			pkgs.difftastic
		];

		extraConfigLua = ''
			require("difftastic-nvim").setup({
				download = false,
				vcs = "jj",
				highlight_mode = "treesitter",
				tree = {
					width = 30,
				},
				snacks_picker = {
					enabled = true,
				},
			})
		'';
	};
}
