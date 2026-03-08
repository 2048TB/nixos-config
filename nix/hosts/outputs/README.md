# outputs 目录

将所有主机汇总为 flake outputs（`nixosConfigurations` / `darwinConfigurations` / `apps` / `checks`）。

---

## 文件

- `default.nix`：总入口（`genSpecialArgs`、`mkApp`、平台聚合）
- `x86_64-linux/default.nix`：NixOS 聚合 + eval tests + pre-commit check + apps
- `aarch64-darwin/default.nix`：Darwin 聚合 + eval tests + apps
- `x86_64-linux/*.nix`、`aarch64-darwin/*.nix`：评估测试表达式与期望值（已扁平化，移除 `tests/` 子目录）

---

## 自动发现

聚合层自动扫描：
- `nix/hosts/nixos/*`（需 `default.nix` + `hardware.nix` + `disko.nix` + `vars.nix`）
- `nix/hosts/darwin/*`（需 `default.nix` + `vars.nix`）

```bash
just hosts
```

---

## apps 行为

- Linux：`apply`、`build`、`build-switch`、`install`、`clean`
- Darwin：`apply`、`build`、`build-switch`、`clean`

apps 内部通过 `nix/scripts/admin/resolve-host.sh ... --strict` 解析主机。

通常无需手动修改此目录，除非新增平台级逻辑（apps/checks/devShell/formatter）。
