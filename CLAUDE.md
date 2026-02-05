# CLAUDE.md

本文件给自动化/AI 工具使用的项目约定。

---

## 行为约束

- 仅在用户明确要求时编辑 `*.md`。
- 输出简洁、直接，中文说明 + 英文技术名词。
- 只做用户请求范围内的改动。

---

## 项目结构

- `flake.nix` 入口，`outputs.nix` 负责输出。
- `nix/hosts/` 主机配置，`nixos-config-hardware.nix` 为安装时生成文件。
- `nix/modules/system.nix` 系统配置。
- `nix/modules/hardware.nix` GPU 选择与驱动配置。
- `nix/home/default.nix` Home Manager 配置。

---

## 关键约定

- 生成文件不要手改：
  - `nix/hosts/nixos-config-hardware.nix`
  - `nix/vars/detected-gpu.txt`
- 安装脚本会将仓库复制到 `/home/<user>/nixos-config` 并写入 `nix/vars/default.nix`。
- GPU 选择来自安装脚本提示或 `NIXOS_GPU`。
- GPU 启动菜单切换默认关闭，需 `ENABLE_GPU_SPECIALISATION=1` 才启用。
- `programs.niri.config = null` 使用手写 KDL 配置。
- `xwayland-satellite` 由 niri 模块集成，不要重复加入 home 包。

---

## 密码与持久化

- 密码文件路径为 `/etc/user-password` 与 `/etc/root-password`。
- 文件由 preservation 从 `/persistent/etc/` 绑定，且 `inInitrd = true`。
- 若改动相关逻辑需确保 initrd 可访问。

---

## 二进制缓存策略

- 避免加入会触发本地编译的包。
- 可用命令检查：

```bash
nix build --dry-run .#nixosConfigurations.nixos-config.config.system.build.toplevel
```
