# outputs 目录

将所有主机汇总为 flake outputs（`nixosConfigurations` / `darwinConfigurations` / `apps` / `checks`），并对外导出可复用接口（`packages` / `overlays` / `nixosModules` / `homeManagerModules`）。

---

## 文件

- `default.nix`：总入口（`genSpecialArgs`、`mkApp`、平台聚合、对外导出面）
- `common.nix`：共享 registry 校验、eval helper、strict host 解析
- `x86_64-linux/default.nix`：NixOS 聚合 + eval tests + pre-commit check + apps
- `aarch64-darwin/default.nix`：Darwin 聚合 + eval tests + apps

---

## 自动发现

聚合层自动扫描：
- `nix/hosts/nixos/*`（需 `hardware.nix` + `hardware-modules.nix` + `disko.nix` + `vars.nix`；`default.nix` 可选）
- `nix/hosts/darwin/*`（需 `default.nix` + `vars.nix`）

```bash
just hosts
```

---

## apps 行为

- Linux：`apply`、`build`、`build-switch`、`install`、`clean`
- Darwin：`apply`、`build`、`build-switch`、`clean`

apps 内部通过 `nix/scripts/admin/resolve-host.sh ... --strict` 解析主机。
eval tests 的通用表达式在 `common.nix`，平台目录只保留各自入口。
对外导出的 `homeManagerModules` 不是 Nix 标准 flake output 名。直接运行原生 `nix flake show/check` 会有 warning，但仓库脚本会过滤这条已知无害提示，不影响退出码。

通常无需手动修改此目录，除非新增平台级逻辑（apps/checks/devShell/formatter）或补充对外复用输出。
