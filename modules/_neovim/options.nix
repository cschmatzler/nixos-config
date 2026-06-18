{
	programs.nixvim = {
		globals = {
			clipboard = "osc52";
			mapleader = " ";
			maplocalleader = " ";
		};
		opts = {
			winborder = "single";
			expandtab = false;
			tabstop = 2;
			ignorecase = true;
			list = false;
			mouse = "";
			relativenumber = true;
			scrolloff = 8;
			shiftwidth = 2;
			smartcase = true;
			diffopt = [
				"internal"
				"filler"
				"closeoff"
				"indent-heuristic"
				"inline:char"
				"linematch:40"
			];
			undofile = true;
		};
	};
}
