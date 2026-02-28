# Hosts Layout

当前仓库按平台分层组织（对齐参考仓库思路）：

- `hosts/vars/default.nix`：全局变量（用户/GPU/密码哈希等）
- `hosts/outputs/<system>/default.nix`：按平台聚合 flake outputs（自动发现主机）
- `hosts/nixos/<host>/hardware.nix`：NixOS 硬件相关配置
- `hosts/nixos/<host>/disko.nix`：NixOS 磁盘/文件系统布局
- `hosts/nixos/<host>/host.nix`：可选，NixOS 主机额外模块（仅在存在时加载）
- `hosts/nixos/<host>/checks.nix`：可选，主机专属 checks（eval 级校验）
- `hosts/nixos/<host>/vars.nix`：可选，主机专属变量覆盖（如 `gpuMode`、`resumeOffset`）
- `hosts/darwin/<host>/default.nix`：Darwin 主机入口
- `hosts/darwin/<host>/checks.nix`：可选，Darwin 主机专属 checks
- `hosts/darwin/<host>/vars.nix`：可选，Darwin 主机专属变量覆盖

新增主机时的最小步骤：

1. NixOS：新建 `hosts/nixos/<host>/` 并至少提供 `hardware.nix` 与 `disko.nix`（可选 `host.nix`）。
2. Darwin：新建 `hosts/darwin/<host>/default.nix`。
3. 按需补充 `checks.nix` 与 `vars.nix`。
4. 通过 `nix eval .#nixosConfigurations --apply builtins.attrNames` 或 `nix eval .#darwinConfigurations --apply builtins.attrNames` 验证自动发现结果。
