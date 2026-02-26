# Home 配置目录

该目录存放 Home Manager 配置与素材。

## 结构

- `default.nix` Home Manager 入口
- `configs/` 配置素材目录
- `configs/niri/` 旧 Niri KDL 配置（已归档，当前未启用）
- `configs/waybar/` Waybar 状态栏
- `configs/wlogout/` Wlogout 电源菜单
- `configs/fuzzel/` Fuzzel 应用启动器
- `configs/foot/` Foot 终端
- `configs/ghostty/` Ghostty 终端
- `configs/hypr/` Hyprland 配置
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

- `configs/niri/*.kdl` 为历史归档文件，当前会话管理器为 Hyprland。
- Waybar 由 systemd 用户服务管理（`systemd.user.services.waybar`）。
- Waybar 网络区采用紧凑架构：`network` + `custom/public-ip` + `custom/wifi-manager`，覆盖链路状态、公网 IP 与 WiFi 管理入口。
- 主题采用统一暗色策略：GTK（`dconf.settings`）+ Qt6（`qt6ct`）+ Wayland 组件单独配色文件。
