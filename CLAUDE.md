# CLAUDE.md

本文件给自动化/AI 工具使用的项目约定。

---

## 行为约束

- 仅在用户明确要求时编辑 `*.md`。
- 输出简洁、直接，中文说明 + 英文技术名词。
- 只做用户请求范围内的改动。
- 涉及 Niri/Waybar/Tmux/Zellij 行为变化时，同步更新 `README.md`、`KEYBINDINGS.md`、`NIX-COMMANDS.md`（必要时含 `nix/home/README.md`）。

---

## 项目结构

- `flake.nix` 入口（inputs/outputs/myvars）。
- `nix/hosts/` 主机配置。
- `nix/modules/system.nix` 系统配置。
- `nix/modules/hardware.nix` GPU 选择与驱动配置。
- `nix/home/default.nix` Home Manager 入口（含 Niri 会话脚本与用户服务）。
- `nix/home/configs/` 应用配置（ghostty/foot/tmux/zellij/waybar/fuzzel 等）。

---

## 关键约定

- GPU 驱动配置固定来自 `flake.nix` 的 `myvars.gpuMode`。
- GPU 启动菜单切换默认关闭，需在 `flake.nix` 中设置 `myvars.enableGpuSpecialisation = true` 才启用。
- 会话管理器为 `Niri`（`programs.niri` + `~/.wayland-session -> niri-session`）。
- `nix/home/configs/niri/*.kdl` 为 Niri 快捷键真源，文档需保持一致。
- `nix/home/configs/tmux/tmux.conf` 与 `nix/home/configs/zellij/config.kdl` 为终端复用器快捷键真源，文档需保持一致。
- `xwayland-satellite` 需保持在系统 PATH（Niri 下 XWayland 应用兼容依赖）。
- 安装流程若依赖 `NIXOS_DISK_DEVICE` 覆盖目标盘，`nixos-install` 需使用 `--impure`。

---

## 密码与持久化

- 密码以哈希写入 `flake.nix` 的 `myvars.userPasswordHash` / `myvars.rootPasswordHash`。
- 不再依赖 `/etc/*-password` 文件或安装脚本。

---

## 二进制缓存策略

- 避免加入会触发本地编译的包。
- 可用命令检查：

```bash
nix build --dry-run .#nixosConfigurations.zly.config.system.build.toplevel
```

---

## 验证与同步

- 文档更新后至少执行：
  - `just fmt`
  - `just lint`
  - `just flake-check`
- 如用户要求同步到 GitHub，按 Conventional Commit 提交并执行 `git push origin HEAD`。
