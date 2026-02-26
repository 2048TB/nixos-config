# Home 配置目录

该目录存放 Home Manager 配置与素材。

## 结构

- `default.nix` Home Manager 入口
- `configs/` 配置素材目录
- `configs/niri/` Niri KDL 配置（当前启用）
- `configs/waybar/` Waybar 历史配置（当前未启用）
- `configs/wlogout/` Wlogout 电源菜单
- `configs/fuzzel/` Fuzzel 应用启动器
- `configs/foot/` Foot 终端
- `configs/ghostty/` Ghostty 终端
- `configs/shell/` Shell 配置（zsh/vim）
- `configs/git/` Git + delta
- `configs/fcitx5/` Fcitx5 输入法
- `configs/qt6ct/` Qt6 主题
- `configs/yazi/` Yazi 文件管理器
- `configs/tmux/` Tmux 终端复用器
- `configs/zellij/` Zellij 终端复用器
- `configs/wallpapers/` 壁纸

## 使用方式

`default.nix` 通过 Home Manager 的 `xdg.configFile` / `home.file` 管理这些配置文件。

应用更改：

```bash
just switch
```

## 重要说明

- 当前会话管理器为 Niri，配置由 `configs/niri/*.kdl` 管理。
- 当前桌面 Shell 为 DankMaterialShell（DMS），由 Home Manager module 管理。
- 主题采用统一暗色策略：GTK（`dconf.settings`）+ Qt6（`qt6ct`）+ Wayland 组件单独配色文件。
