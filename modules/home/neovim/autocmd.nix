{
	programs.nixvim = {
		autoGroups = {
			Christoph = {};
		};

		autoCmd = [
			{
				event = "BufWritePre";
				group = "Christoph";
				pattern = "*";
				command = "%s/\\s\\+$//e";
			}
			{
				event = "BufReadPost";
				group = "Christoph";
				pattern = "*";
				command = "normal zR";
			}
			{
				event = "FileReadPost";
				group = "Christoph";
				pattern = "*";
				command = "normal zR";
			}
		];
	};
}
