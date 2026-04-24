{inputs, ...}: final: prev: {
	pi-mcp-adapter =
		prev.buildNpmPackage {
			pname = "pi-mcp-adapter";
			version = "2.5.1";
			src = inputs.pi-mcp-adapter;
			npmDepsFetcherVersion = 2;
			npmDepsHash = "sha256-2JQzjxMy0+rtDq6bO2tpyZ1X+cZclRzsCDzDklC/bxc=";
			dontNpmBuild = true;
		};
}
