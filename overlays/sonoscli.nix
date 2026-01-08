{inputs}: final: prev: {
	sonoscli =
		prev.buildGoModule rec {
			pname = "sonoscli";
			version = "0.1.0";

			src =
				prev.fetchFromGitHub {
					owner = "steipete";
					repo = "sonoscli";
					rev = "v${version}";
					hash = "sha256-9ouRJ0Rr+W5Kx9BltgW29Jo1Jq7Hb/un4XBkq+0in9o=";
				};

			vendorHash = "sha256-hocnLCzWN8srQcO3BMNkd2lt0m54Qe7sqAhUxVZlz1k=";

			subPackages = ["cmd/sonos"];

			meta = with prev.lib; {
				description = "Control SONOS speakers from your terminal";
				homepage = "https://github.com/steipete/sonoscli";
				license = licenses.mit;
				mainProgram = "sonos";
			};
		};
}
