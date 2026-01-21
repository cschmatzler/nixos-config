{...}: {
	programs.aerospace = {
		enable = true;
		launchd.enable = true;
		settings = {
			"accordion-padding" = 30;
			"default-root-container-layout" = "tiles";
			"default-root-container-orientation" = "auto";
			"on-focused-monitor-changed" = [
				"move-mouse monitor-lazy-center"
			];

			gaps = {
				inner = {
					horizontal = 8;
					vertical = 8;
				};
				outer = {
					left = 8;
					right = 8;
					top = 8;
					bottom = 8;
				};
			};

			"on-window-detected" = [
				{
					"if" = {
						"app-id" = "com.apple.systempreferences";
					};
					run = "layout floating";
				}
				{
					"if" = {
						"app-id" = "com.mitchellh.ghostty";
					};
					run = "layout tiling";
				}
			];

			mode = {
				main.binding = {
					"alt-enter" = "exec-and-forget open -a Ghostty";
					"alt-h" = "focus left";
					"alt-j" = "focus down";
					"alt-k" = "focus up";
					"alt-l" = "focus right";
					"alt-shift-h" = "move left";
					"alt-shift-j" = "move down";
					"alt-shift-k" = "move up";
					"alt-shift-l" = "move right";
					"alt-ctrl-h" = "focus-monitor --wrap-around left";
					"alt-ctrl-j" = "focus-monitor --wrap-around down";
					"alt-ctrl-k" = "focus-monitor --wrap-around up";
					"alt-ctrl-l" = "focus-monitor --wrap-around right";
					"alt-ctrl-shift-h" = "move-node-to-monitor --focus-follows-window --wrap-around left";
					"alt-ctrl-shift-j" = "move-node-to-monitor --focus-follows-window --wrap-around down";
					"alt-ctrl-shift-k" = "move-node-to-monitor --focus-follows-window --wrap-around up";
					"alt-ctrl-shift-l" = "move-node-to-monitor --focus-follows-window --wrap-around right";
					"alt-space" = "layout tiles accordion";
					"alt-shift-space" = "layout floating tiling";
					"alt-slash" = "layout horizontal vertical";
					"alt-f" = "fullscreen";
					"alt-tab" = "workspace-back-and-forth";
					"alt-shift-tab" = "move-workspace-to-monitor --wrap-around next";
					"alt-r" = "mode resize";
					"alt-shift-semicolon" = "mode service";
					"alt-1" = "workspace 1";
					"alt-2" = "workspace 2";
					"alt-3" = "workspace 3";
					"alt-4" = "workspace 4";
					"alt-5" = "workspace 5";
					"alt-6" = "workspace 6";
					"alt-7" = "workspace 7";
					"alt-8" = "workspace 8";
					"alt-9" = "workspace 9";
					"alt-shift-1" = "move-node-to-workspace --focus-follows-window 1";
					"alt-shift-2" = "move-node-to-workspace --focus-follows-window 2";
					"alt-shift-3" = "move-node-to-workspace --focus-follows-window 3";
					"alt-shift-4" = "move-node-to-workspace --focus-follows-window 4";
					"alt-shift-5" = "move-node-to-workspace --focus-follows-window 5";
					"alt-shift-6" = "move-node-to-workspace --focus-follows-window 6";
					"alt-shift-7" = "move-node-to-workspace --focus-follows-window 7";
					"alt-shift-8" = "move-node-to-workspace --focus-follows-window 8";
					"alt-shift-9" = "move-node-to-workspace --focus-follows-window 9";
				};
				resize.binding = {
					"h" = "resize width -50";
					"j" = "resize height +50";
					"k" = "resize height -50";
					"l" = "resize width +50";
					"enter" = "mode main";
					"esc" = "mode main";
				};
				service.binding = {
					"esc" = "mode main";
					"r" = ["reload-config" "mode main"];
					"b" = ["balance-sizes" "mode main"];
					"f" = ["layout floating tiling" "mode main"];
					"backspace" = ["close-all-windows-but-current" "mode main"];
				};
			};
		};
	};
}
