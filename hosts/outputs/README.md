# Outputs Layout

此目录按平台聚合 flake outputs，管理方式参考 `dustinlyons/nixos-config`，并做了本仓库的最小化实现。

## 目录约定

- `hosts/outputs/default.nix`：顶层聚合（`nixosConfigurations`、`darwinConfigurations`、`apps`、`checks`、`devShells`、`formatter`）
- `hosts/outputs/<system>/default.nix`：平台聚合入口（自动发现 `hosts/<platform>/*`）
- `hosts/outputs/<system>/tests/*`：平台 eval tests（hostname/home 等）

## 主机注册流程

1. NixOS：在 `hosts/nixos/<host>/` 下必须提供 `hardware.nix`、`disko.nix`、`vars.nix`（可选 `host.nix`）。
2. Darwin：在 `hosts/darwin/<host>/` 下必须提供 `default.nix` 与 `vars.nix`。
3. 按需添加 `home.nix`、`modules/`、`home-modules/`、`checks.nix`（建议保留，便于主机独立演进）。
4. `hosts/outputs/<system>/default.nix` 会自动扫描 `hosts/<platform>/*` 聚合主机。
5. `flake.nix` 统一通过 `outputs = inputs: import ./hosts/outputs inputs;` 接入该聚合层，无需手工注册主机名。

## 设计目标

- 多主机可扩展：新增主机只需新增 `hosts/<platform>/<name>/` 目录。
- 平台聚合清晰：平台级 apps/checks/devShell/formatter 统一在 `hosts/outputs/<system>/default.nix`。
- 行为可验证：通过 `nix flake check` 和 `nix eval .#checks.<system>` 做快速回归。

## Flake Apps

- `apps` 提供 `nix run .#<name>` 入口（如 `build` / `build-switch` / `install` / `clean`）。
- 实现位于各平台 `hosts/outputs/<system>/default.nix`，底层复用仓库 `just` 命令。
- 主机选择优先级：环境变量（`NIXOS_HOST` / `DARWIN_HOST`）> 当前 hostname 自动匹配 > 默认回退主机。
- 若默认回退主机不可用，会自动选择仓库内第一个可用主机并输出 warning。
