{inputs, ...}: final: prev: {
	pi-agent-stuff =
		prev.buildNpmPackage {
			pname = "pi-agent-stuff";
			version = "1.5.0";
			src = inputs.pi-agent-stuff;
			npmDepsHash = "sha256-pyXMNdlie8vAkhz2f3GUGT3CCYuwt+xkWnsijBajXIo=";
			dontNpmBuild = true;
		};
}
