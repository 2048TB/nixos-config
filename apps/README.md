# Flake Apps

本仓库提供 flake app 入口，便于在任意目录用 `nix run` 执行常用操作。

## 常用命令

```bash
# 自动按当前 hostname 解析主机
nix run .#build
nix run .#build-switch

# 仅 NixOS 提供安装入口（Live ISO 场景）
nix run .#install

# 清理旧世代
nix run .#clean
```

## 主机解析规则

主机由 `scripts/resolve-host.sh` 解析，优先级如下：

1. `NIXOS_HOST` / `DARWIN_HOST`
2. 当前机器 `hostname`
3. `justfile` 或 app 内置默认主机回退

若检测到的主机不在仓库中，会自动回退到可用主机并输出 warning。

## 与 `just` 的关系

- flake apps 底层复用 `just` 命令（例如 `build-switch -> just switch/darwin-switch`）。
- 日常建议优先 `just switch-local` / `just check-local`。
- 需要跨目录或脚本化调用时，使用 `nix run .#<app>` 更方便。

## 常见环境变量

```bash
# 指定 NixOS 主机
NIXOS_HOST=zky nix run .#build-switch

# 指定 Darwin 主机
DARWIN_HOST=zly-mac nix run .#build-switch

# 安装目标磁盘（NixOS）
NIXOS_DISK_DEVICE=/dev/nvme0n1 nix run .#install

# 显式仓库路径
NIXOS_CONFIG_REPO=/persistent/nixos-config nix run .#build
```
