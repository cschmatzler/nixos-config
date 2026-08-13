_: let
  commonNetworkHosts = [
    "api.github.com"
    "codeload.github.com"
    "crates.io"
    "files.pythonhosted.org"
    "github.com"
    "github-releases.githubusercontent.com"
    "index.crates.io"
    "objects.githubusercontent.com"
    "pypi.org"
    "raw.githubusercontent.com"
    "registry.npmjs.org"
    "static.crates.io"
    ((import ../../_lib/local.nix).tailscaleHost "executor")
  ];
  sensitivePaths = [
    "/nix/var/nix/daemon-socket"
    "/run/docker.sock"
    "/run/secrets"
    "/var/run/docker.sock"
    "$HOME/.config/herdr"
    "$HOME/.config/sops"
    "$HOME/.local/state/herdr-sandbox"
  ];
  commonGroups = [
    "node_runtime"
    "python_runtime"
    "rust_runtime"
    "nix_runtime"
    "git_config"
    "unlink_protection"
  ];
  commonEnvironment = {
    allow_vars = [
      "COLORTERM"
      "EDITOR"
      "FORCE_COLOR"
      "HOME"
      "LANG"
      "LC_*"
      "LESS"
      "LOGNAME"
      "NIX_PATH"
      "NIX_PROFILES"
      "NIX_SSL_CERT_FILE"
      "NO_COLOR"
      "PAGER"
      "PATH"
      "SHELL"
      "SSL_CERT_FILE"
      "TERM"
      "TERM_PROGRAM"
      "TERM_PROGRAM_VERSION"
      "TZ"
      "USER"
      "VISUAL"
      "XDG_CACHE_HOME"
      "XDG_CONFIG_HOME"
      "XDG_DATA_HOME"
      "XDG_RUNTIME_DIR"
      "XDG_STATE_HOME"
    ];
  };
  supermemoryCredential = {
    upstream = "https://api.supermemory.ai";
    credential_key = "file://${(import ../../_lib/local.nix).secretPath "supermemory-api-key"}";
    env_var = "SUPERMEMORY_API_KEY";
    inject_header = "Authorization";
    credential_format = "Bearer {}";
  };
  mkProfile = {
    name,
    description,
    filesystem,
    environment ? {},
    network,
    openUrls ? null,
  }:
    {
      extends = "default";
      meta = {
        inherit name description;
        version = "1.0.0";
      };
      groups.include = commonGroups;
      security = {
        signal_mode = "isolated";
        capability_elevation = false;
      };
      linux.af_unix_mediation = "pathname";
      inherit filesystem;
      environment = commonEnvironment // environment;
      inherit network;
      workdir.access = "readwrite";
      interactive = true;
    }
    // (
      if openUrls == null
      then {}
      else {open_urls = openUrls;}
    );
  # Pi stores OAuth credentials below .pi. The official nono Pi pack does not
  # broker them yet, so this compatibility grant remains until a Pi-specific
  # OAuth capture flow has been proven end to end.
  piFilesystem = {
    deny = sensitivePaths;
    allow = [
      "@git:common-dir"
      "$HOME/.cache/nvim"
      "$HOME/.local/share/nvim"
      "$HOME/.local/share/opensrc"
      "$HOME/.local/state/nvim"
      "$HOME/.npm"
      "$HOME/.pi"
      "$HOME/.plannotator"
      "$NONO_CONFIG/profile-drafts"
    ];
    # pi-claude-auth reads and refreshes this exact Claude Code OAuth file.
    allow_file = ["$HOME/.claude/.credentials.json"];
    unix_socket = ["/run/nscd/socket"];
    unix_socket_subtree_bind = ["$HOME/.pi/tmp"];
    read_file = [
      "$HOME/.config/gh/config.yml"
      "$HOME/.config/gh/hosts.yml"
    ];
    read = [
      "$HOME/.agents/skills"
      "$HOME/.config/nvim"
      "$HOME/.npm-global"
      "$NONO_CONFIG/profiles"
      "$NONO_PACKAGES"
    ];
  };
  piEnvironment = {
    set_vars.TMPDIR = "$HOME/.pi/tmp";
    allow_vars =
      commonEnvironment.allow_vars
      ++ [
        "PI_CACHE_RETENTION"
        "PI_CODING_AGENT_DIR"
        "PI_OFFLINE"
        "PI_SKIP_VERSION_CHECK"
        "PI_TELEMETRY"
        "PLANNOTATOR_PORT"
        "PLANNOTATOR_REMOTE"
      ];
  };
  piNetwork = {
    block = false;
    allow_domain =
      commonNetworkHosts
      ++ [
        "api.anthropic.com"
        "api.openai.com"
        "auth.openai.com"
        "chatgpt.com"
        "claude.ai"
        "claude.com"
        "platform.claude.com"
      ];
    credentials = ["supermemory"];
    custom_credentials.supermemory = supermemoryCredential;
    listen_port = [
      1455
      20000
    ];
  };
  claudeFilesystem = {
    deny = sensitivePaths;
    allow = [
      "@git:common-dir"
      "$HOME/.cache/claude"
      "$HOME/.cache/claude-cli-nodejs"
      "$HOME/.cache/nvim"
      "$HOME/.claude"
      "$HOME/.local/share/nvim"
      "$HOME/.local/share/opensrc"
      "$HOME/.local/state/nvim"
      "$HOME/.local/state/claude/locks"
      "$HOME/.npm"
      "$HOME/.plannotator"
      "$NONO_CONFIG/profile-drafts"
    ];
    allow_file = [
      "$HOME/.claude.json"
      "$HOME/.claude.json.lock"
      "$HOME/.claude.lock"
    ];
    unix_socket = ["/run/nscd/socket"];
    unix_socket_subtree_bind = ["$HOME/.claude/tmp"];
    read_file = [
      "$HOME/.config/gh/config.yml"
      "$HOME/.config/gh/hosts.yml"
    ];
    read = [
      "$HOME/.config/nvim"
      "$HOME/.npm-global"
      "$NONO_CONFIG/profiles"
      "$NONO_PACKAGES"
    ];
  };
  claudeEnvironment = {
    set_vars.TMPDIR = "$HOME/.claude/tmp";
    allow_vars =
      commonEnvironment.allow_vars
      ++ [
        "CLAUDE_CONFIG_DIR"
        "DISABLE_AUTOUPDATER"
        "PLANNOTATOR_PORT"
        "PLANNOTATOR_REMOTE"
      ];
  };
  claudeNetwork = {
    block = false;
    allow_domain =
      commonNetworkHosts
      ++ [
        "api.anthropic.com"
        "claude.ai"
        "claude.com"
        "platform.claude.com"
      ];
    listen_port = [20000];
  };
in {
  # Updated through `nix run .#update -- nono-packs`; review pack policy and
  # plugin changes before applying the new lock.
  flake-file.inputs.nono-packs = {
    url = "github:nolabs-ai/nono-packs";
    flake = false;
  };

  den.aspects.nono.homeManager = {
    inputs',
    pkgs,
    ...
  }: let
    jsonFormat = pkgs.formats.json {};
    piProfile = mkProfile {
      name = "pi";
      description = "Pi with explicit filesystem, environment, and network capabilities";
      filesystem = piFilesystem;
      environment = piEnvironment;
      network = piNetwork;
      openUrls = {
        allow_origins = [
          "https://auth.openai.com"
          "https://claude.ai"
          "https://github.com"
        ];
        allow_localhost = true;
      };
    };
    claudeProfile = mkProfile {
      name = "claude";
      description = "Claude Code with explicit filesystem, environment, and network capabilities";
      filesystem = claudeFilesystem;
      environment = claudeEnvironment;
      network = claudeNetwork;
      openUrls = {
        allow_origins = [
          "https://claude.ai"
          "https://claude.com"
          "https://platform.claude.com"
        ];
        allow_localhost = true;
      };
    };
  in {
    home = {
      packages = [inputs'.llm-agents.packages.nono];
      sessionVariables = {
        NONO_NO_PACK_UPDATE_HINTS = "1";
        NONO_NO_UPDATE_CHECK = "1";
      };
      file = {
        ".config/nono/profiles/pi.json".source = jsonFormat.generate "nono-pi-profile.json" piProfile;
        ".config/nono/profiles/claude.json".source = jsonFormat.generate "nono-claude-profile.json" claudeProfile;
        ".config/nono/profile-drafts/.keep".text = "";
      };
    };
  };
}
