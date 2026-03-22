{inputs, ...}: final: prev: {
	pi-mcp-adapter =
		prev.buildNpmPackage {
			pname = "pi-mcp-adapter";
			version = "2.2.0";
			src = inputs.pi-mcp-adapter;
			npmDepsHash = "sha256-myJ9h/zC/KDddt8NOVvJjjqbnkdEN4ZR+okCR5nu7hM=";
			dontNpmBuild = true;
		};
}
