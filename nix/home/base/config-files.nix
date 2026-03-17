{
  sharedSourceFiles = {
    "git/config" = ../configs/git/config;
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
