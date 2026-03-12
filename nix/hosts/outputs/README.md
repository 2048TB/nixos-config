# outputs 目录

将所有主机汇总为 flake outputs（`nixosConfigurations` / `darwinConfigurations` / `apps` / `checks`），并对外导出可复用接口（`packages` / `overlays` / `nixosModules`）。
当前仓库的 CI 只消费其中少量 read-only 能力；不要把本目录理解为自动 deploy / switch 入口。

---

## 文件

- `default.nix`：总入口（`genSpecialArgs`、`mkApp`、平台聚合、对外导出面）
- `common.nix`：共享 registry 校验与 eval helper
- `x86_64-linux/default.nix`：NixOS 聚合 + eval tests + pre-commit check + apps
- `aarch64-darwin/default.nix`：Darwin 聚合 + eval tests + apps

---

## 自动发现

聚合层自动扫描：
- `nix/hosts/nixos/*`（需 `hardware.nix` + `hardware-modules.nix` + `disko.nix` + `vars.nix`；`default.nix` 可选）
- `nix/hosts/darwin/*`（需 `default.nix` + `vars.nix`）

## apps 行为

- Linux：仅保留 `install`
- Darwin：当前不再导出 app

`install` app 读取 `NIXOS_HOST`；未设置时会直接报错退出，避免误装到默认 host。
eval tests 的通用表达式在 `common.nix`，平台目录只保留各自入口。

通常无需手动修改此目录，除非新增平台级逻辑（apps/checks/devShell/formatter）或补充对外复用输出。
若只是新增主机或调机器参数，优先改 `nix/hosts/<platform>/<host>/` 与 `nix/hosts/registry/systems.toml`，不要先动本目录。
