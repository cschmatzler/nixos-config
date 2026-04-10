{inputs, ...}: final: prev: {
	pi-mcp-adapter =
		prev.buildNpmPackage {
			pname = "pi-mcp-adapter";
			version = "2.2.0";
			src = inputs.pi-mcp-adapter;
			npmDepsHash = "sha256-6dw9Wbxnc2HXRDl9Aw4YYV2lDplJcWiJa16C6Kz2WOI=";
			dontNpmBuild = true;
		};
}
