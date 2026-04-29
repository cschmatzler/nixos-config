{inputs, ...}: final: prev: {
	pi-mcp-adapter =
		prev.buildNpmPackage {
			pname = "pi-mcp-adapter";
			version = "2.5.2";
			src = inputs.pi-mcp-adapter;
			npmDepsFetcherVersion = 2;
			npmDepsHash = "sha256-J8ogEjKmO3yYBGGJSpNVoaVKKgGFt9vjcEJUxVV9tq0=";
			dontNpmBuild = true;
		};
}
