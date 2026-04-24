{...}: final: prev: let
	paperlessStdenv =
		prev.stdenv
		// {
			mkDerivation = arg:
				prev.stdenv.mkDerivation (
					if builtins.isFunction arg
					then
						finalAttrs: let
							attrs = arg finalAttrs;
						in
							if (attrs.pname or null) == "paperless-ngx-frontend"
							then attrs // {doCheck = false;}
							else attrs
					else if (arg.pname or null) == "paperless-ngx-frontend"
					then arg // {doCheck = false;}
					else arg
				);
		};
in {
	paperless-ngx =
		prev.paperless-ngx.override {
			stdenv = paperlessStdenv;
		};
}
