{inputs, ...}: final: prev: {
	pi-agent-stuff =
		prev.buildNpmPackage {
			pname = "pi-agent-stuff";
			version = "1.6.0";
			src = inputs.pi-agent-stuff;
			npmDepsHash = "sha256-E/i6zBUEd3P82sxHUlcb6rJHVftcM2Bvm6UTL+Md+uo=";
			dontNpmBuild = true;
		};
}
