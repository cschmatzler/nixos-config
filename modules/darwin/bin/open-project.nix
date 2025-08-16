{pkgs}:
pkgs.writeShellScriptBin "open-project" ''
    TARGET=$(fd -t d --exact-depth 1 . $HOME/Projects |
  	sed "s~$HOME/Projects/~~" |
  	fzf --prompt "project > ")

  zellij run -i -- /${pkgs.fish}/bin/fish -c "cd $HOME/Projects/$TARGET; fish"
''
