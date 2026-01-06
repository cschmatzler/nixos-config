{pkgs, ...}: {
	xdg.configFile."ghostty/config".text = ''
		command = ${pkgs.fish}/bin/fish
		theme = Catppuccin Latte
		window-padding-x = 12
		window-padding-y = 3
		window-padding-balance = true
		font-family = TX-02
		font-size = 16.5
		cursor-style = block
		mouse-hide-while-typing = true
		mouse-scroll-multiplier = 1.25
		shell-integration = detect
		shell-integration-features = no-cursor
		clipboard-read = allow
		clipboard-write = allow

		keybind = ctrl+t>n=new_tab
		keybind = ctrl+t>x=close_tab
		keybind = ctrl+t>h=previous_tab
		keybind = ctrl+t>left=previous_tab
		keybind = ctrl+t>k=previous_tab
		keybind = ctrl+t>up=previous_tab
		keybind = ctrl+t>l=next_tab
		keybind = ctrl+t>right=next_tab
		keybind = ctrl+t>j=next_tab
		keybind = ctrl+t>down=next_tab
		keybind = ctrl+t>tab=last_tab
		keybind = ctrl+t>one=goto_tab:1
		keybind = ctrl+t>two=goto_tab:2
		keybind = ctrl+t>three=goto_tab:3
		keybind = ctrl+t>four=goto_tab:4
		keybind = ctrl+t>five=goto_tab:5
		keybind = ctrl+t>six=goto_tab:6
		keybind = ctrl+t>seven=goto_tab:7
		keybind = ctrl+t>eight=goto_tab:8
		keybind = ctrl+t>nine=goto_tab:9

		keybind = ctrl+p>n=new_split:auto
		keybind = ctrl+p>d=new_split:down
		keybind = ctrl+p>r=new_split:right
		keybind = ctrl+p>x=close_surface
		keybind = ctrl+p>f=toggle_split_zoom
		keybind = ctrl+p>h=goto_split:left
		keybind = ctrl+p>left=goto_split:left
		keybind = ctrl+p>l=goto_split:right
		keybind = ctrl+p>right=goto_split:right
		keybind = ctrl+p>j=goto_split:down
		keybind = ctrl+p>down=goto_split:down
		keybind = ctrl+p>k=goto_split:up
		keybind = ctrl+p>up=goto_split:up
		keybind = ctrl+p>equal=equalize_splits

		keybind = ctrl+n>h=resize_split:left,10
		keybind = ctrl+n>left=resize_split:left,10
		keybind = ctrl+n>j=resize_split:down,10
		keybind = ctrl+n>down=resize_split:down,10
		keybind = ctrl+n>k=resize_split:up,10
		keybind = ctrl+n>up=resize_split:up,10
		keybind = ctrl+n>l=resize_split:right,10
		keybind = ctrl+n>right=resize_split:right,10
		keybind = ctrl+n>equal=equalize_splits

		keybind = alt+n=new_split:auto
		keybind = alt+h=goto_split:left
		keybind = alt+l=goto_split:right
		keybind = alt+j=goto_split:down
		keybind = alt+k=goto_split:up
	'';
}
