{
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };

  home.sessionVariables = {
    FZF_DEFAULT_OPTS = ''
      --bind=alt-k:up,alt-j:down
      --expect=tab,enter
      --layout=reverse
      --delimiter='\t'
      --with-nth=1
      --preview-window='border-rounded' --prompt='  ' --marker=' ' --pointer=' '
      --separator='─' --scrollbar='┃' --layout='reverse'

      --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
      --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
      --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
      --color=selected-bg:#45475a
      --color=border:#6c7086,label:#cdd6f4
    '';
  };
}
