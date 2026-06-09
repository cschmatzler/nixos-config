{...}: {
	den.aspects.herdr.homeManager = {inputs', ...}: {
		home.packages = [
			inputs'.herdr.packages.herdr
		];

		home.file.".config/herdr/config.toml".text = ''
			[theme]
			name = "rose-pine-dawn"

			[keys]
			prefix = "ctrl+semicolon"
		'';
	};
}
