_: let
  local = import ../../_lib/local.nix;
in {
  den.aspects.plannotator = {
    homeManager = {
      inputs',
      pkgs,
      ...
    }: let
      # Upstream's bun is broken on aarch64-darwin for this package; pin one that works.
      bun = pkgs.bun.overrideAttrs {
        version = "1.3.11";
        src = pkgs.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.11/bun-darwin-aarch64.zip";
          hash = "sha256-b1o0Z+2crsR5W/eM1HZQfZ+HDH1XuGyUX8szgSZ3L/w=";
        };
      };
      upstream = inputs'.llm-agents.packages.plannotator;
      plannotator =
        if pkgs.stdenv.hostPlatform.isDarwin
        then
          upstream.overrideAttrs (old: {
            nativeBuildInputs =
              [pkgs.darwin.autoSignDarwinBinariesHook]
              ++ map (input:
                if (input.pname or null) == "bun"
                then bun
                else input)
              old.nativeBuildInputs;
          })
        else upstream;
    in {
      home.packages = [plannotator];
      home.sessionVariables = {
        PLANNOTATOR_PORT = "20000";
        PLANNOTATOR_REMOTE = "1";
      };
      home.file.".plannotator/config.json".source = (pkgs.formats.json {}).generate "plannotator-config.json" {
        diffOptions = {
          defaultDiffType = "since-base";
          diffStyle = "split";
          diffIndicators = "bars";
          lineDiffType = "word-alt";
          fontFamily = "";
        };
        displayName = local.user.fullName;
        prompts.review.runtimes.pi.denied = ''
          The comments above are review directions written by the user. Treat them as intentional and correct by default, and address each one. Use the code to determine the right implementation. If a direction appears incorrect or harmful, raise the specific concern instead of following it blindly. Do not treat the comments as automated or unverified feedback, and do not require a verdict for each one.

          Review only the submitted comments. Do not independently review the rest of the diff or search for issues that were not submitted.
        '';
      };
    };

    nixos = {pkgs, ...}: {
      systemd.services.plannotator-tailscale = import ../../_lib/tailscale-serve.nix {
        inherit pkgs;
        identity = "svc:plannotator";
        port = 20000;
      };
    };
  };
}
