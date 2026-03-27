{ config, mylib, myvars, osConfig ? null, ... }:
let
  homeDir = config.home.homeDirectory;
  localShareDir = "${homeDir}/.local/share";
  localBinDir = "${homeDir}/.local/bin";
  hostCfg = import ./resolve-host.nix { inherit myvars osConfig; };
in
{
  programs = {
    starship = {
      enable = true;
      enableZshIntegration = true;
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
      changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border"
      ];
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      initContent = builtins.readFile ../configs/shell/zshrc;
    };

    vim = {
      enable = true;
      extraConfig = builtins.readFile ../configs/shell/vimrc;
    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;
      # ~/.ssh/ 由 Home Manager 管理（指向 nix store，只读），
      # 将 known_hosts 指向可写位置，避免 SSH 无法自动写入新 host key。
      # GitHub 的 host key 已通过 home.file 预填。
      extraConfig = ''
        UserKnownHostsFile ${homeDir}/.local/share/ssh/known_hosts
      '';
      matchBlocks."*".addKeysToAgent = "yes";
      matchBlocks."github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "${homeDir}/.ssh/id_ed25519";
        identitiesOnly = true;
      };
    };
  };

  home = {
    stateVersion = hostCfg.homeStateVersion or mylib.defaultHomeStateVersion;

    # GitHub host key 种子：activation 时写入可写的 known_hosts 路径，
    # 确保首次 SSH 连接无需交互确认；后续 SSH 仍可追加新 host key。
    activation.seedSshKnownHosts = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      kh="${homeDir}/.local/share/ssh/known_hosts"
      mkdir -p "$(dirname "$kh")"
      if [ ! -f "$kh" ]; then
        cat > "$kh" << 'KNOWNHOSTS'
      github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
      github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
      KNOWNHOSTS
      fi
    '';

    sessionVariables = {
      NIX_HOSTNAME = hostCfg.hostname;
      NPM_CONFIG_PREFIX = "${homeDir}/.npm-global";
      BUN_INSTALL = "${homeDir}/.bun";
      BUN_INSTALL_BIN = "${homeDir}/.bun/bin";
      BUN_INSTALL_GLOBAL_DIR = "${homeDir}/.bun/install/global";
      BUN_INSTALL_CACHE_DIR = "${homeDir}/.bun/install/cache";
      UV_TOOL_DIR = "${localShareDir}/uv/tools";
      UV_TOOL_BIN_DIR = "${localShareDir}/uv/bin";
      UV_PYTHON_DOWNLOADS = "never";
      PYTHONUSERBASE = "${homeDir}/.local";
      CARGO_HOME = "${homeDir}/.cargo";
      GOPATH = "${homeDir}/go";
      GOBIN = "${homeDir}/go/bin";
      PIPX_HOME = "${localShareDir}/pipx";
      PIPX_BIN_DIR = "${localShareDir}/pipx/bin";
    };

    sessionPath = [
      "${homeDir}/.npm-global/bin"
      "${homeDir}/tools"
      "${homeDir}/.bun/bin"
      "${homeDir}/.cargo/bin"
      "${homeDir}/go/bin"
      "${localShareDir}/pnpm/bin"
      "${localShareDir}/pipx/bin"
      "${localShareDir}/uv/bin"
      localBinDir
    ];
  };
}
