{homeDirectory, ...}: {
	hooks = {
		UserPromptSubmit = [
			{
				hooks = [
					{
						type = "command";
						command = "node ${homeDirectory}/.codex/supermemory/recall.js";
						timeout = 90;
						statusMessage = "Searching memories...";
					}
				];
			}
		];
		Stop = [
			{
				hooks = [
					{
						type = "command";
						command = "node ${homeDirectory}/.codex/supermemory/flush.js";
						timeout = 60;
						statusMessage = "Saving to memory...";
					}
				];
			}
		];
	};
}
