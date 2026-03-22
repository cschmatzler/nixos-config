{inputs, ...}: final: prev: {
	ast-grep =
		prev.ast-grep.overrideAttrs (old: {
				doCheck = false;
			});
}
