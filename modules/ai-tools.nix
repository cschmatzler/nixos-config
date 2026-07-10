{
  den,
  inputs,
  ...
}: {
  flake-file.inputs = {
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.flake-parts.follows = "flake-parts";
    };
    nono = {
      url = "github:always-further/nono";
      flake = false;
    };
  };

  den.aspects.ai-tools = {
    includes = [
      den.aspects.codex
      den.aspects.node-runtime
      den.aspects.opencode
    ];
    homeManager = {pkgs, ...}: {
      home = {
        packages = [
          (pkgs.callPackage ./_packages/nono.nix {nonoSrc = inputs.nono;})
        ];
        sessionVariables.PLANNOTATOR_REMOTE = "1";
      };
    };
  };
}
