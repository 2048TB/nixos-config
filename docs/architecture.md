# Architecture

仓库结构与职责分层见：

- `nix/hosts/README.md`
- `nix/home/README.md`

简要概览：

- `flake.nix`: 入口
- `nix/hosts/outputs`: flake outputs 聚合
- `nix/modules/core`: NixOS 系统模块
- `nix/modules/darwin`: Darwin 系统模块
- `nix/home/*`: Home Manager 配置
- `nix/scripts/admin`: 运维脚本
- `nix/scripts/checks`: 仓库/registry/input 检查脚本
