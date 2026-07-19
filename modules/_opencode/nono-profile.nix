{
  meta = {
    name = "opencode";
    description = "OpenCode coding agent profile with restricted network, OpenAI and OpenCode access, MCP access, and NixOS development tooling.";
    version = "1.0.0";
  };

  extends = "default";

  groups.include = [
    "git_config"
    "go_runtime"
    "java_runtime"
    "linux_runtime_state"
    "linux_sysfs_read"
    "linux_temp_read"
    "nix_runtime"
    "node_runtime"
    "python_runtime"
    "rust_runtime"
    "user_caches_linux"
  ];

  workdir.access = "readwrite";

  filesystem = {
    allow = [
      "$HOME/.cache/opencode"
      "$HOME/.config/opencode"
      "$HOME/.local/share/opencode"
      "$HOME/.local/state/opencode"
      "$HOME/.npm"
      "$HOME/.npm-global"
      "$HOME/Projects/worktrees"
    ];
    read = [
      "$HOME/.config/nix"
      "$HOME/.local/state/nix"
    ];
    unix_socket = [
      "$HOME/.config/herdr/herdr.sock"
    ];
    bypass_protection = [
      "$HOME/.config/opencode"
    ];
  };

  security = {
    process_info_mode = "isolated";
    signal_mode = "isolated";
    wsl2_proxy_policy = "error";
  };

  network = {
    network_profile = "opencode";
    allow_domain = [
      "*.chatgpt.com"
      "*.executor.sh"
      "*.openai.com"
      "*.opencode.ai"
      "api.github.com"
      "api.openai.com"
      "auth.openai.com"
      "cache.nixos.org"
      "chatgpt.com"
      "codeload.github.com"
      "crates.io"
      "executor.sh"
      "files.pythonhosted.org"
      "github.com"
      "index.crates.io"
      "nono.sh"
      "npm.pkg.github.com"
      "objects.githubusercontent.com"
      "openai.com"
      "opencode.ai"
      "proxy.golang.org"
      "pypi.org"
      "raw.githubusercontent.com"
      "registry.npmjs.org"
      "static.crates.io"
      "sum.golang.org"
    ];
    open_port = [
      3000
      5173
      8000
      8080
      8228
      19432
    ];
  };

  environment = {
    allow_vars = [
      "COLORTERM"
      "EDITOR"
      "HERDR_*"
      "HOME"
      "LANG"
      "LC_*"
      "NIX_*"
      "NIXOS_*"
      "OPENAI_*"
      "OPENCODE_*"
      "PATH"
      "SHELL"
      "SSH_AUTH_SOCK"
      "TERM"
      "TERM_PROGRAM"
      "TMPDIR"
      "USER"
      "XDG_*"
    ];
    set_vars = {
      GIT_EDITOR = "true";
      GIT_MERGE_AUTOEDIT = "no";
      GIT_SEQUENCE_EDITOR = "true";
    };
  };
}
