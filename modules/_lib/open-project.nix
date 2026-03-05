{pkgs}:
pkgs.writeShellScriptBin "open-project" ''
	TARGET=$(fd -t d --exact-depth 1 . $HOME/Projects |
		sed "s~$HOME/Projects/~~" |
		fzf --prompt "project > ")

	if [ -n "$TARGET" ]; then
		echo "$HOME/Projects/$TARGET"
	fi
''
