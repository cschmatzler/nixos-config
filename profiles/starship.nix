{
	programs.starship = {
		enable = true;
		enableFishIntegration = true;
		settings = {
			add_newline = true;
			command_timeout = 2000;
			format = "[$directory$\{custom.scm}]($style)$character";
			character = {
				error_symbol = "[✗ ](bold #e64553)";
				success_symbol = "[❯](bold #40a02b)[❯](bold #df8e1d)[❯](bold #dc8a78)";
			};
			directory = {
				truncation_length = 2;
				truncation_symbol = "…/";
				repo_root_style = "bold cyan";
				repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) ";
			};
			custom.scm = {
				when = "jj-starship detect";
				shell = ["jj-starship" "--strip-bookmark-prefix" "cschmatzler/" "--truncate-name" "20" "--bookmarks-display-limit" "1"];
				format = "$output ";
			};
		};
	};
}
