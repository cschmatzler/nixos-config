{
	programs.nixvim = {
		globals = {
			clipboard = "osc52";
		};
		opts = {
			expandtab = false;
			tabstop = 2;
			ignorecase = true;
			mouse = "";
			relativenumber = true;
			shiftwidth = 2;
			smartcase = true;
		};
	};
}
