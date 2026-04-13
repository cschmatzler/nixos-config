{inputs, ...}: final: prev: {
	pi-mcp-adapter =
		prev.buildNpmPackage {
			pname = "pi-mcp-adapter";
			version = "2.3.4";
			src = inputs.pi-mcp-adapter;
			postPatch = ''
				substituteInPlace package.json \
					--replace-fail '    "open": "^10.2.0",' "" \
					--replace-fail '    "@types/bun": "^1.0.0",' "" \
					--replace-fail '    "@types/open": "^6.2.1",' "" \
					--replace-fail '    "tsx": "^4.21.0",' ""
			'';
			npmDepsFetcherVersion = 2;
			npmDepsHash = "sha256-NO86vWd5lSBo/PaRzzaW3fTJ3sSqI6XyIFUfM3GVtkM=";
			dontNpmBuild = true;
		};
}
