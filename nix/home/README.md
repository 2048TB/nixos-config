# Home 配置目录

该目录存放 Home Manager 配置与素材。

## 结构

- `base/default.nix` 跨平台共享 Home 配置
- `linux/default.nix` Linux Home 配置（Niri/Waybar/systemd user services）
- `darwin/default.nix` Darwin Home 配置模板
- `configs/` 配置素材目录
- `configs/niri/` Niri KDL 配置（当前启用，按 `input/layout/animations/output` 拆分）
- `configs/waybar/` Waybar 状态栏
- `configs/wlogout/` Wlogout 电源菜单
- `configs/fuzzel/` Fuzzel 应用启动器
- `configs/foot/` Foot 终端
- `configs/ghostty/` Ghostty 终端
- `configs/hypr/` Hyprland 配置（历史保留）
- `configs/shell/` Shell 配置（zsh/vim）
- `configs/git/` Git + delta
- `configs/fcitx5/` Fcitx5 输入法
- `configs/qt6ct/` Qt6 主题
- `configs/yazi/` Yazi 文件管理器
- `configs/tmux/` Tmux 终端复用器
- `configs/zellij/` Zellij 终端复用器
- `configs/wallpapers/` 壁纸

## 使用方式

`linux/default.nix` 通过 Home Manager 的 `xdg.configFile` / `home.file` 管理这些配置文件。

应用更改：

```bash
just switch
```

## 重要说明

- `configs/niri/*.kdl` 为当前会话管理器 Niri 配置。
- `configs/tmux/tmux.conf` 与 `configs/zellij/config.kdl` 为终端复用器快捷键配置真源；`KEYBINDINGS.md` 需与其一致。
- Waybar 由 systemd 用户服务管理（`systemd.user.services.waybar`）。
- Waybar 当前模块以 `niri/workspaces`、`niri/window`、`mpris`、`custom/public-ip`、`backlight`、`battery`、`tray` 等为主，详见 `configs/waybar/config.jsonc`。
- 主题采用统一暗色策略：GTK（`dconf.settings`）+ Qt6（`qt6ct`）+ Wayland 组件单独配色文件。
- `linux/default.nix` 会生成多个脚本包装器（如 `waybar-launcher`、`wlogout-menu`）；配置调试时优先检查这些生成脚本与对应 systemd 用户服务。
- `darwin/default.nix` 内置按平台可用性过滤包；不可用包会记录为 Home Manager warnings，不再导致评估失败。`ghostty` 由 `hosts/darwin/zly-mac/default.nix` 的 `homebrew.casks` 安装，Homebrew 本体由 `nix-homebrew` 自动接管安装。

## Niri Typed 配置评估

- 当前方案：使用 `configs/niri/*.kdl` + `xdg.configFile`，优点是直观、可直接对照上游 KDL 文档。
- 候选方案：引入 `niri-flake` 的 `programs.niri.settings`，通过 typed options 生成配置并在构建期校验。
- 建议迁移顺序：
  1. 先保持现有 KDL 作为稳定基线；
  2. 在单独分支试点把 `input/layout/output/animations` 映射到 `programs.niri.settings`；
  3. 完成等价验证后再迁移 `binds/window-rules/spawn-at-startup`。
- 参考：`niri-flake` 文档对 `programs.niri.settings` 与 build-time validation 的说明（docs.md）。

## 常用排查

```bash
systemctl --user status waybar.service --no-pager
journalctl --user -b -u waybar.service -u xdg-desktop-portal.service --no-pager
```
