{
  config,
  pkgs,
}: let
  theme = (import ../../../_lib/theme.nix).rosePineDawn;
  toolSettings = import ./tool-settings.nix {inherit pkgs;};
in
  toolSettings
  // {
    # Appearance and editor behavior mirror the shared Neovim configuration.
    "workbench.colorTheme" = theme.displayName;
    "workbench.iconTheme" = "vs-seti";
    "window.autoDetectColorScheme" = false;
    "window.commandCenter" = false;
    "breadcrumbs.enabled" = false;
    "workbench.startupEditor" = "none";
    "workbench.secondarySideBar.defaultVisibility" = "hidden";
    "workbench.layoutControl.enabled" = false;
    "workbench.activityBar.showAccounts" = false;
    "workbench.tips.enabled" = false;
    "workbench.welcomePage.walkthroughs.openOnInstall" = false;
    "workbench.enableExperiments" = false;
    "workbench.editor.enablePreview" = false;
    "workbench.editor.enablePreviewFromQuickOpen" = false;

    # Keep AI, recommendations, release notes, and telemetry out of the UI.
    "chat.disableAIFeatures" = true;
    "chat.commandCenter.enabled" = false;
    "workbench.settings.showAISearchToggle" = false;
    "extensions.ignoreRecommendations" = true;
    "extensions.showRecommendationsOnlyOnDemand" = true;
    "extensions.autoUpdate" = false;
    "update.showReleaseNotes" = false;
    "telemetry.telemetryLevel" = "off";

    "editor.fontFamily" = "TX-02, monospace";
    "editor.fontSize" = 14;
    "editor.fontLigatures" = false;
    "editor.lineNumbers" = "relative";
    "editor.tabSize" = 2;
    "editor.insertSpaces" = true;
    "editor.detectIndentation" = false;
    "editor.scrollBeyondLastLine" = false;
    "editor.cursorSurroundingLines" = 8;
    "editor.cursorSurroundingLinesStyle" = "all";
    "editor.minimap.enabled" = false;
    "editor.stickyScroll.enabled" = false;
    "editor.renderWhitespace" = "none";
    "editor.wordWrap" = "off";
    "editor.formatOnSave" = true;
    "editor.formatOnSaveMode" = "file";
    "editor.bracketPairColorization.enabled" = true;
    "editor.guides.bracketPairs" = true;
    "editor.inlayHints.enabled" = "on";

    "files.autoSave" = "off";
    "files.exclude"."**/.git" = false;
    "search.smartCase" = true;
    "explorer.compactFolders" = false;
    "explorer.confirmDelete" = false;
    "explorer.confirmDragAndDrop" = false;

    "diffEditor.renderSideBySide" = false;
    "diffEditor.ignoreTrimWhitespace" = false;
    "diffEditor.hideUnchangedRegions.enabled" = true;
    "diffEditor.hideUnchangedRegions.contextLineCount" = 3;

    "terminal.integrated.fontFamily" = "TX-02";
    "terminal.integrated.fontSize" = 14;
    "terminal.integrated.cursorStyle" = "block";
    "terminal.integrated.cursorBlinking" = false;
    "terminal.integrated.profiles.osx".fish.path = "${pkgs.fish}/bin/fish";
    "terminal.integrated.profiles.linux".fish.path = "fish";
    "terminal.integrated.defaultProfile.osx" = "fish";
    "terminal.integrated.defaultProfile.linux" = "fish";

    # Keep formatters and language servers aligned with the Neovim setup.
    "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
    "[javascript][javascriptreact][typescript][typescriptreact]"."editor.defaultFormatter" = "oxc.oxc-vscode";

    "git.confirmSync" = false;
    "git.openRepositoryInParentFolders" = "always";

    # vscode-neovim runs on the Mac even while the workspace is on tahani.
    "vscode-neovim.neovimExecutablePaths.darwin" = "${config.programs.nixvim.build.package}/bin/nvim";
    "vscode-neovim.neovimInitVimPaths.darwin" = "${config.xdg.configHome}/vscode-neovim/init.lua";
    "remote.extensionKind" = {
      "asvetliakov.vscode-neovim" = ["ui"];
    };

    "remote.SSH.remotePlatform".tahani = "linux";
    "remote.SSH.defaultExtensions" = [
      "jnoortheen.nix-ide"
      "oxc.oxc-vscode"
    ];
  }
