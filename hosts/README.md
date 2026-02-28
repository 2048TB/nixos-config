# Hosts Layout

当前仓库按平台分层组织（对齐参考仓库思路）：

- `hosts/nixos/<host>/default.nix`：NixOS 主机入口（拼装 imports）
- `hosts/nixos/default.nix`：NixOS 平台公共配置入口（所有 NixOS 主机共享）
- `hosts/nixos/<host>/hardware.nix`：硬件相关配置
- `hosts/nixos/<host>/disko.nix`：磁盘/文件系统布局
- `hosts/nixos/<host>/home.nix`：可选，NixOS 主机专属 Home Manager 配置
- `hosts/nixos/<host>/checks.nix`：可选，主机专属 checks（eval 级校验）
- `hosts/darwin/<host>/default.nix`：Darwin 主机入口
- `hosts/darwin/default.nix`：Darwin 平台公共配置入口（所有 macOS 主机共享）
- `hosts/darwin/<host>/home.nix`：Darwin 主机专属 Home Manager 配置
- `hosts/darwin/<host>/checks.nix`：可选，Darwin 主机专属 checks

新增主机时的最小步骤：

1. 在 `hosts/nixos/` 或 `hosts/darwin/` 下新建主机目录并放置 `default.nix`（NixOS 还需 `hardware.nix`/`disko.nix`）。
2. 新建 `outputs/<system>/src/<host>.nix` 并关联该主机目录。
3. 通过 `nix eval .#nixosConfigurations --apply builtins.attrNames` 或 `nix eval .#darwinConfigurations --apply builtins.attrNames` 验证已被自动发现。
