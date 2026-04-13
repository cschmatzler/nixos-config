{inputs, ...}: final: prev: {
	pi-mcp-adapter =
		prev.buildNpmPackage {
			pname = "pi-mcp-adapter";
			version = "2.3.4";
			src = inputs.pi-mcp-adapter;
			postPatch = ''
				# Upstream 2.3.4 ships a stale package-lock.json that omits runtime deps like
				# `open`, so replace it with a lockfile regenerated from upstream package.json.
				cp ${./pi-mcp-adapter-package-lock.json} package-lock.json
			'';
			npmDepsFetcherVersion = 2;
			npmDepsHash = "sha256-cX9uptTUe8EQnp9RzQnlk4Dz6mqre73nCrf/cNYR0ug=";
			dontNpmBuild = true;
		};
}
