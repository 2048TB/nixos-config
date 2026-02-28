# Outputs Layout

此目录按平台聚合 flake outputs，结构参考 `ryan4yin/nix-config`，并做了本仓库的最小化实现。

## 目录约定

- `outputs/default.nix`：顶层聚合（`nixosConfigurations`、`darwinConfigurations`、`checks`、`devShells`、`formatter`）
- `outputs/<system>/src/<host>.nix`：主机注册入口（尽量保持薄）
- `outputs/<system>/tests/*`：平台 eval tests（hostname/home 等）

## 主机注册流程

1. 新建 `outputs/<system>/src/<host>.nix`。
2. 在 `hosts/nixos/` 或 `hosts/darwin/` 下新增对应目录与 `default.nix`（可选 `home.nix`/`checks.nix`）。
3. `outputs/<system>/default.nix` 会自动扫描 `src/*.nix` 聚合主机。

## 设计目标

- 多主机可扩展：新增主机只改单个 `src` 文件与对应 `hosts/<platform>/<name>/` 目录。
- 平台聚合清晰：平台级 checks/devShell/formatter 统一在 `outputs/<system>/default.nix`。
- 行为可验证：通过 `nix flake check` 和 `nix eval .#checks.<system>` 做快速回归。
