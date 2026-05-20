{
	pkgs,
	theme,
	clipboardTool,
}: ''
	# vim: set ft=tmux:

	# tmux sensible see: https://github.com/tmux-plugins/tmux-sensible
	set -s escape-time 0
	set -g history-limit 50000
	set -g display-time 4000
	set -g status-interval 5
	set -g default-terminal "tmux-256color"

	# Enable extended keys (CSI u encoding) for proper modifier key support
	set -s extended-keys always
	set -s extended-keys-format csi-u

	# Tell tmux the outer terminal supports extended keys
	set -s terminal-features 'xterm*:clipboard:ccolour:cstyle:focus:title:extkeys'
	set -as terminal-features 'screen*:title'
	set -as terminal-features 'rxvt*:ignorefkeys'

	# Emacs key bindings in tmux command prompt (prefix + :)
	set -g status-keys emacs

	# Focus events enabled for terminals that support them
	set -g focus-events on

	# Super useful when using "grouped sessions" and multi-monitor setup
	setw -g aggressive-resize on

	# Set shell to fish
	set-option -g default-shell ${pkgs.fish}/bin/fish

	# Unbind <C-b> as the prefix key
	unbind C-b

	# Bind <C-;> as the prefix key
	unbind C-\;
	set -g prefix C-\;
	bind \; send-prefix

	# Enable mouse support
	set -g mouse on

	# Pane resizing with vim-like keys (-r allows repeat without prefix)
	bind -r - resize-pane -D 2
	bind -r = resize-pane -U 2
	bind -r ] resize-pane -R 2
	bind -r [ resize-pane -L 2

	# Bind delete key to equalize all panes using tiled layout
	bind -r DC select-layout tiled

	# Window and pane creation with current path preservation
	unbind %
	unbind '"'
	bind \\ split-window -h -c "#{pane_current_path}"
	bind Enter split-window -v -c "#{pane_current_path}"
	bind c new-window -c "#{pane_current_path}"

	# Bind x to kill current pane
	bind x kill-pane

	# Bind m to maximize the current pane
	unbind z
	unbind m
	bind m resize-pane -Z

	# Bind r to reload tmux config
	unbind r
	bind r source-file ~/.tmux.conf \; display "Config reloaded"

	# Enable vim keys for copy mode
	set-window-option -g mode-keys vi

	# Copy mode with vim-like keybindings
	bind v copy-mode

	bind -T copy-mode-vi q send-keys -X cancel
	bind -T copy-mode-vi v send-keys -X begin-selection
	bind -T copy-mode-vi V send-keys -X select-line
	bind -T copy-mode-vi Escape send-keys -X clear-selection
	bind -T copy-mode-vi 'C-v' send-keys -X rectangle-toggle
	bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "${clipboardTool}"
	bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe "${clipboardTool}"
	bind -T copy-mode MouseDragEnd1Pane send-keys -X copy-pipe "${clipboardTool}"

	# Status bar positioning
	set-option -g status-position top

	# Start window and pane numbering at 1 (more intuitive than 0)
	set -g base-index 1
	set -g pane-base-index 1
	set-window-option -g pane-base-index 1
	set-option -g renumber-windows on

	# Enable pane navigation while in copy mode (works with vim-tmux-navigator)
	bind -T copy-mode-vi 'C-h' select-pane -L
	bind -T copy-mode-vi 'C-j' select-pane -D
	bind -T copy-mode-vi 'C-k' select-pane -U
	bind -T copy-mode-vi 'C-l' select-pane -R
	bind -T copy-mode-vi 'C-\\' select-pane -l
	bind -T copy-mode-vi 'C-Space' select-pane -t:.+

	# Theme Configuration
	# IMPORTANT: Theme must load BEFORE continuum to avoid overwriting status-right
	set -g @rose_pine_variant 'dawn'
	set -g @rose_pine_directory 'on'

	# Session persistence - save and restore tmux sessions
	set -g @resurrect-strategy-vim 'session'
	set -g @resurrect-strategy-nvim 'session'
	set -g @resurrect-capture-pane-contents 'on'

	# Automatic session save/restore
	set -g @continuum-restore 'on'
	set -g @continuum-boot 'on'
	set -g @continuum-save-interval '10'
''
