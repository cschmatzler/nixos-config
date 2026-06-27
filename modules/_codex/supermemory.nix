{...}: {
	similarityThreshold = 0.6;
	maxMemories = 5;
	maxProfileItems = 5;
	injectProfile = true;
	containerTagPrefix = "codex";
	filterPrompt = "You are a stateful coding agent. Remember all the information, including but not limited to user's coding preferences, tech stack, behaviours, workflows, and any other relevant details.";
	debug = false;

	signalExtraction = false;
	signalKeywords = [
		"prefer"
		"like"
		"love"
		"use"
		"hate"
		"dislike"
		"avoid"
		"remember"
		"forget"
		"note"
		"decision"
		"decided"
		"chose"
		"choose"
		"picked"
		"switched"
		"moved"
		"migrated"
		"architecture"
		"pattern"
		"approach"
		"design"
		"tradeoff"
		"implementation"
		"refactor"
		"upgrade"
		"deprecate"
		"bug"
		"fix"
		"fixed"
		"solved"
		"solution"
		"important"
		"stack"
		"framework"
		"library"
		"tool"
		"database"
	];
	signalTurnsBefore = 3;
	autoSaveEveryTurns = 3;
}
