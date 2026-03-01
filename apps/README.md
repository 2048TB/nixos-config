# Flake Apps

本仓库提供统一的 flake app 入口（参考 `dustinlyons/nixos-config` 与 `ryan4yin/nix-config` 的做法）：

```bash
nix run .#build
nix run .#build-switch
nix run .#install
nix run .#clean
```

## 主机解析策略

默认优先级：
1. 显式环境变量（`NIXOS_HOST` / `DARWIN_HOST`）
2. 当前机器 hostname 自动匹配 flake 中已注册主机
3. 回退默认主机（NixOS: `zly`，Darwin: `zly-mac`）

实现脚本：`scripts/resolve-host.sh`

底层执行关系（当前实现）：
- Linux: `build -> just check`，`build-switch/apply -> just switch`，`install -> just install-live`
- Darwin: `build -> just darwin-check`，`build-switch/apply -> just darwin-switch`

## 常用示例

```bash
# 当前机器自动匹配主机（推荐）
nix run .#build-switch

# 指定目标 NixOS 主机
NIXOS_HOST=zky nix run .#build-switch

# 指定目标 Darwin 主机
DARWIN_HOST=zly-mac nix run .#build-switch

# Live ISO 安装指定磁盘
NIXOS_DISK_DEVICE=/dev/nvme0n1 nix run .#install
```
