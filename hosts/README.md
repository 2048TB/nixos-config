# Hosts Layout

当前仓库采用“精简但可扩展”的多主机结构：

- `hosts/nixos/<host>/`：NixOS 主机目录（必需：`hardware.nix` + `disko.nix` + `vars.nix`）
- `hosts/darwin/<host>/`：Darwin 主机目录（必需：`default.nix` + `vars.nix`）
- `hosts/<platform>/<host>/home.nix`：该主机专属 Home Manager 覆盖（可选）
- `hosts/<platform>/<host>/checks.nix`：该主机专属 checks（可选，建议保留）
- `hosts/<platform>/<host>/modules/`：主机额外 module（可选）
- `hosts/<platform>/<host>/home-modules/`：主机额外 home module（可选）

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
   - 预览：`just new-nixos-host-dry-run <host>` / `just new-darwin-host-dry-run <host>`
   - 覆盖：`just new-nixos-host-force <host>` / `just new-darwin-host-force <host>`
2. 按需调整 `vars.nix` / `disko.nix` / `hardware.nix` / `home.nix`。
3. 运行：
   - `nix eval .#nixosConfigurations --apply builtins.attrNames`
   - `nix eval .#darwinConfigurations --apply builtins.attrNames`
   - `just eval-tests`

主机自动解析（`switch-local` / `check-local`）优先级：

1. `NIXOS_HOST` / `DARWIN_HOST`
2. 当前 `hostname`
3. 默认回退主机（若默认不可用则回退到仓库内首个可用主机）

严格模式（用于危险/变更系统操作，如 `install-live-local` 与 flake apps 的 `apply/build-switch/install`）：

1. `NIXOS_HOST` / `DARWIN_HOST`
2. 当前 `hostname`
3. 未命中直接失败（不使用 fallback）
