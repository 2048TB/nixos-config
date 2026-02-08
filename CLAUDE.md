# CLAUDE.md

本文件给自动化/AI 工具使用的项目约定。

---

## 行为约束

- 仅在用户明确要求时编辑 `*.md`。
- 输出简洁、直接，中文说明 + 英文技术名词。
- 只做用户请求范围内的改动。

---

## 项目结构

- `flake.nix` 入口并包含 outputs。
- `nix/hosts/` 主机配置。
- `nix/modules/system.nix` 系统配置。
- `nix/modules/hardware.nix` GPU 选择与驱动配置。
- `nix/home/default.nix` Home Manager 配置。

---

## 关键约定

- GPU 驱动配置固定来自 `flake.nix` 的 `myvars.gpuMode`。
- GPU 启动菜单切换默认关闭，需 `ENABLE_GPU_SPECIALISATION=1` 才启用。
- `programs.niri.config = null` 使用手写 KDL 配置。
- `xwayland-satellite` 由 niri 模块集成，不要重复加入 home 包。
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
