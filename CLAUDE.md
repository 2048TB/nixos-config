# CLAUDE.md

本文件给自动化/AI 工具使用的项目约定。

---

## 行为约束

- 仅在用户明确要求时编辑 `*.md`。
- 输出简洁、直接，中文说明 + 英文技术名词。
- 只做用户请求范围内的改动。
- 目录整理任务优先“最小差异 + 保持现有可用性”，不要引入无关重构。
- 涉及 Niri/Waybar/Tmux/Zellij 行为变化时，同步更新 `README.md`、`KEYBINDINGS.md`、`NIX-COMMANDS.md`（必要时含 `nix/home/README.md`）。
- 涉及流程规范变化时，同步更新 `CLAUDE.md` 与 `AGENTS.md`。

---

## 项目结构

- `flake.nix` 入口（inputs/nixConfig/outputs）。
- `hosts/nixos/<host>/vars.nix` 参数配置（username/gpu/password hash 等，NixOS 必需）。
- `hosts/darwin/<host>/vars.nix` 参数配置（至少含 username，Darwin 必需）。
- `hosts/outputs/` 按平台聚合 flake outputs（自动发现主机）。
- `hosts/` 主机配置（如 `hosts/nixos/zly/{hardware.nix,disko.nix}`、`hosts/darwin/zly-mac/default.nix`）。
- `scripts/resolve-host.sh` 主机自动解析（`NIXOS_HOST`/`DARWIN_HOST` > hostname > fallback，不可用时自动选可用主机）。
- `scripts/new-host.sh` 主机脚手架（复制模板主机生成新目录）。
- `lib/default.nix` 公共工具与系统装配入口（`nixosSystem`/`macosSystem`/`mk*Host`）。
- `apps/README.md` flake apps 入口说明（`nix run .#build-switch` 等）。
- `nix/modules/system.nix` 系统配置。
- `nix/modules/hardware.nix` GPU 选择与驱动配置。
- `nix/home/linux/default.nix` Linux Home Manager 入口。
- `nix/home/base|linux|darwin` Home 分层配置。
- `nix/home/configs/` 应用配置（ghostty/foot/tmux/zellij/waybar/fuzzel 等）。

---

## 关键约定

- GPU 驱动配置固定来自 `hosts/nixos/<host>/vars.nix` 的 `gpuMode`。
- NixOS 服务开关默认由 `hosts/nixos/<host>/vars.nix` 的 `roles` 决定（仍可用 `enable*` 显式覆盖）。
- `zly` / `zky` 主机目录按“独立文件”维护，不做 host-level 共享 import（便于后续差异化）。
- GPU 启动菜单切换默认关闭，需在对应主机 `vars.nix` 中设置 `enableGpuSpecialisation = true` 才启用。
- 会话管理器为 `Niri`（`programs.niri` + `~/.wayland-session -> niri-session`）。
- `nix/home/configs/niri/*.kdl` 为 Niri 快捷键真源，文档需保持一致。
- `nix/home/configs/tmux/tmux.conf` 与 `nix/home/configs/zellij/config.kdl` 为终端复用器快捷键真源，文档需保持一致。
- `xwayland-satellite` 需保持在系统 PATH（Niri 下 XWayland 应用兼容依赖）。
- 安装流程若依赖 `NIXOS_DISK_DEVICE` 覆盖目标盘，`nixos-install` 需使用 `--impure`。
- 管理入口同时支持 `just` 与 flake `apps`（`nix run .#<app>`）。
- 日常优先使用：`just switch-local` / `just check-local` / `just test-local` / `just darwin-*-local`。
- 主机脚手架支持预览与强制覆盖：`just new-*-host-dry-run` / `just new-*-host-force`。

---

## 密码与持久化

- 密码以哈希写入对应主机 `hosts/nixos/<host>/vars.nix` 的 `userPasswordHash` / `rootPasswordHash`。
- 不再依赖 `/etc/*-password` 等外部密码文件；安装统一使用命令流程。

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
  - `just eval-tests`
  - `just flake-check`
- 如变更涉及 Nix 文件，再补充：
  - `just fmt`
  - `just lint`
- 如用户要求同步到 GitHub，按 Conventional Commit 提交并执行 `git push origin HEAD`。
