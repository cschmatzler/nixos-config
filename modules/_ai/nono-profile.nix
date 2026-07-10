{
  name,
  description,
  writablePaths,
  bypassProtection,
  serviceDomains,
  additionalDomains ? [],
  apiEnvironmentVariables,
}: {
  meta = {
    inherit name description;
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
    allow =
      writablePaths
      ++ [
        "$HOME/.npm"
        "$HOME/.npm-global"
        "$HOME/.plannotator"
        "$HOME/Projects/worktrees"
      ];
    read = [
      "$HOME/.config/nix"
      "$HOME/.local/state/nix"
    ];
    unix_socket = [
      "$HOME/.config/herdr/herdr.sock"
    ];
    bypass_protection = bypassProtection;
  };

  security = {
    process_info_mode = "isolated";
    signal_mode = "isolated";
    wsl2_proxy_policy = "error";
  };

  network = {
    network_profile = name;
    allow_domain =
      serviceDomains
      ++ [
        "executor.sh"
        "*.executor.sh"
        "api.github.com"
        "cache.nixos.org"
        "codeload.github.com"
        "crates.io"
        "files.pythonhosted.org"
        "github.com"
        "index.crates.io"
        "npm.pkg.github.com"
        "nono.sh"
        "objects.githubusercontent.com"
      ]
      ++ additionalDomains
      ++ [
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
      19432
    ];
  };

  environment.allow_vars =
    [
      "COLORTERM"
      "EDITOR"
      "HERDR_*"
      "HOME"
      "LANG"
      "LC_*"
      "NIX_*"
      "NIXOS_*"
      "PLANNOTATOR_*"
    ]
    ++ apiEnvironmentVariables
    ++ [
      "PATH"
      "SHELL"
      "SSH_AUTH_SOCK"
      "TERM"
      "TERM_PROGRAM"
      "TMPDIR"
      "USER"
      "XDG_*"
    ];
}
