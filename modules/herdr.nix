{...}: let
  theme = (import ./_lib/theme.nix).catppuccinMocha;
in {
  den.aspects.herdr.homeManager = {inputs', ...}: {
    home.packages = [
      inputs'.herdr.packages.herdr
    ];

    home.file.".config/herdr/config.toml".text = ''
      onboarding = false

      [theme]
      name = "${theme.slug}"

      [terminal]
      default_shell = "fish"
      new_cwd = "follow"
      shell_mode = "auto"

      [worktrees]
      directory = "~/Projects/worktrees"

      [ui]
      sidebar_width = 32
      sidebar_min_width = 18
      sidebar_max_width = 36
      mouse_capture = true
      right_click_passthrough_modifier = "ctrl"
      mouse_scroll_lines = 3
      confirm_close = false
      show_agent_labels_on_pane_borders = true
      agent_panel_scope = "all"
      prompt_new_tab_name = true
      accent = "${theme.hex.mauve}"

      [ui.toast]
      delivery = "terminal"
      delay_seconds = 1

      [ui.sound]
      enabled = false

      [session]
      resume_agents_on_restore = true

      [remote]
      manage_ssh_config = true

      [experimental]
      pane_history = true
      allow_nested = false
      kitty_graphics = true

      [advanced]
      scrollback_limit_bytes = 50000000

      [keys]
      prefix = "ctrl+b"

      help = "prefix+?"
      settings = "prefix+shift+s"
      detach = ["prefix+d", "prefix+q"]
      reload_config = "prefix+r"
      goto = "prefix+g"
      last_pane = "prefix+backtick"
      open_notification_target = "prefix+o"

      workspace_picker = ["prefix+s", "prefix+w"]
      new_workspace = "prefix+shift+n"
      rename_workspace = "prefix+shift+w"
      close_workspace = "prefix+shift+d"
      previous_workspace = "prefix+("
      next_workspace = "prefix+)"
      switch_workspace = "prefix+shift+1..9"

      focus_agent = "prefix+alt+1..9"
      previous_agent = "prefix+["
      next_agent = "prefix+]"

      new_tab = "prefix+c"
      previous_tab = "prefix+p"
      next_tab = "prefix+n"
      switch_tab = "prefix+1..9"
      rename_tab = "prefix+comma"
      close_tab = "prefix+shift+x"

      split_vertical = "prefix+backslash"
      split_horizontal = "prefix+enter"
      close_pane = "prefix+x"
      zoom = "prefix+m"
      copy_mode = "prefix+v"
      resize_mode = "prefix+shift+r"
      focus_pane_left = ["ctrl+h"]
      focus_pane_down = ["ctrl+j"]
      focus_pane_up = ["ctrl+k"]
      focus_pane_right = ["ctrl+l"]
      cycle_pane_next = "prefix+tab"
      cycle_pane_previous = "prefix+shift+tab"
      toggle_sidebar = "prefix+b"

      navigate_workspace_up = "up"
      navigate_workspace_down = "down"
      navigate_pane_left = "h"
      navigate_pane_down = "j"
      navigate_pane_up = "k"
      navigate_pane_right = "l"
    '';
  };
}
