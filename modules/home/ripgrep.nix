{
	programs.ripgrep = {
		enable = true;
		arguments = [
			"--max-columns=150"
			"--max-columns-preview"
			"--smart-case"
			"--colors=column:none"
			"--colors=column:fg:4"
			"--colors=column:style:underline"
			"--colors=line:none"
			"--colors=line:fg:4"
			"--colors=match:none"
			"--colors=match:bg:0"
			"--colors=match:fg:6"
			"--colors=path:none"
			"--colors=path:fg:14"
			"--colors=path:style:bold"
		];
	};
}
