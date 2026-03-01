# Hosts Layout

当前仓库采用“精简但可扩展”的多主机结构：

- `hosts/nixos/<host>/`：NixOS 主机目录（至少 `hardware.nix` + `disko.nix` + `vars.nix`）
- `hosts/darwin/<host>/`：Darwin 主机目录（至少 `default.nix` + `vars.nix`）
- `hosts/<platform>/<host>/home.nix`：该主机专属 Home Manager 覆盖（可选）
- `hosts/<platform>/<host>/checks.nix`：该主机专属 checks（可选，建议保留）

与主机关联的 Home Manager 主机层位于：

- `hosts/nixos/zly/home.nix`
- `hosts/nixos/zky/home.nix`
- `hosts/darwin/zly-mac/home.nix`

主机维护策略（当前约定）：

- `zly` 与 `zky` 采用“独立文件”维护，不做 host-level 共享 import。
- 即使现阶段配置接近，也保留各自主机文件，优先保证后续差异化可演进。

新增主机建议步骤（最小变更）：

1. 用脚手架生成目录：
   - `just new-nixos-host <host>`（默认模板 `zly`）
   - `just new-darwin-host <host>`（默认模板 `zly-mac`）
2. 按需调整 `vars.nix` / `disko.nix` / `hardware.nix` / `home.nix`。
3. 运行：
   - `nix eval .#nixosConfigurations --apply builtins.attrNames`
   - `nix eval .#darwinConfigurations --apply builtins.attrNames`
   - `just eval-tests`
