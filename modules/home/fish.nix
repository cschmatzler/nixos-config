{
  programs.fish = {
    enable = true;
    functions = {
      open_project = ''
        set -l base "$HOME/Projects"
        set -l choice (fd -t d -d 1 -a . "$base/Personal" "$base/Work" \
            | string replace -r -- "^$base/" "" \
            | fzf --prompt "project > ")
        test -n "$choice"; and cd "$base/$choice"
      '';
    };
    interactiveShellInit = ''
      set fish_greeting

      set fish_color_normal cdd6f4
      set fish_color_command 89b4fa
      set fish_color_param f2cdcd
      set fish_color_keyword f38ba8
      set fish_color_quote a6e3a1
      set fish_color_redirection f5c2e7
      set fish_color_end fab387
      set fish_color_comment 7f849c
      set fish_color_error f38ba8
      set fish_color_gray 6c7086
      set fish_color_selection --background=313244
      set fish_color_search_match --background=313244
      set fish_color_option a6e3a1
      set fish_color_operator f5c2e7
      set fish_color_escape eba0ac
      set fish_color_autosuggestion 6c7086
      set fish_color_cancel f38ba8
      set fish_color_cwd f9e2af
      set fish_color_user 94e2d5
      set fish_color_host 89b4fa
      set fish_color_host_remote a6e3a1
      set fish_color_status f38ba8
      set fish_pager_color_progress 6c7086
      set fish_pager_color_prefix f5c2e7
      set fish_pager_color_completion cdd6f4
      set fish_pager_color_description 6c7086

      set -gx LS_COLORS "$(vivid generate catppuccin-mocha)"

      for mode in default insert
        bind --mode $mode \cp open_project
      end
    '';
  };
}
