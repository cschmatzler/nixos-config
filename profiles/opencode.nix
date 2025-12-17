{
	inputs,
	pkgs,
	...
}: {
	programs.opencode = {
		enable = true;
		package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
		settings = {
			theme = "catppuccin";
			instructions = [
				"CLAUDE.md"
				"AGENT.md"
				"AGENTS.md"
			];
			formatter = {
				mix = {
					disabled = true;
				};
			};
			command = {
				deslop = {
					description = "Remove AI code slop";
					template = ''
						Check the diff against main/master, and remove all AI generated slop introduced in this branch.
						Use jj if available, otherwise git.

						This includes:

						- Extra comments that a human wouldn't add or is inconsistent with the rest of the file
						- Extra defensive checks or try/catch blocks that are abnormal for that area of the codebase (especially if called by trusted / validated codepaths)
						- Casts to any to get around type issues
						- Any other style that is inconsistent with the file
						- Unnecessary emoji usage

						Report at the end with only a 1-3 sentence summary of what you changed
					'';
				};
			};
		};
	};
	home.sessionVariables = {
		OPENCODE_EXPERIMENTAL_EXA = "true";
	};
}
