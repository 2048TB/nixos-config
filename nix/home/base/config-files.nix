{
  sharedSourceFiles = {
    "git/config" = ../configs/git/config;
    "mise/config.toml" = ../configs/mise/config.toml;
    "television/config.toml" = ../configs/television/config.toml;
    "television/cable/alias.toml" = ../configs/television/cable/alias.toml;
    "television/cable/dirs.toml" = ../configs/television/cable/dirs.toml;
    "television/cable/env.toml" = ../configs/television/cable/env.toml;
    "television/cable/files.toml" = ../configs/television/cable/files.toml;
    "television/cable/git-branch.toml" = ../configs/television/cable/git-branch.toml;
    "television/cable/git-diff.toml" = ../configs/television/cable/git-diff.toml;
    "television/cable/git-log.toml" = ../configs/television/cable/git-log.toml;
    "television/cable/git-repos.toml" = ../configs/television/cable/git-repos.toml;
    "television/cable/text.toml" = ../configs/television/cable/text.toml;
    "yazi/yazi.toml" = ../configs/yazi/yazi.toml;
    "yazi/keymap.toml" = ../configs/yazi/keymap.toml;
  };

  darwinSourceFiles = {
    "ghostty/config" = ../configs/ghostty/config;
    "tmux/tmux.conf" = ../configs/tmux/tmux.conf;
    "zellij/config.kdl" = ../configs/zellij/config.kdl;
  };

  linuxSourceFiles = { };

  linuxForcedSourceFiles = {
    "fcitx5/profile" = ../configs/fcitx5/profile;
  };

  linuxThemedFiles = {
    "fuzzel/fuzzel.ini" = ../configs/fuzzel/fuzzel.ini;
    "foot/foot.ini" = ../configs/foot/foot.ini;
    "ghostty/config" = ../configs/ghostty/config;
    "zellij/config.kdl" = ../configs/zellij/config.kdl;
    "tmux/tmux.conf" = ../configs/tmux/tmux.conf;
  };
}
