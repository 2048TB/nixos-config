# outputs 目录

本目录负责把 hosts 聚合成 flake outputs，并提供共享校验入口。它不是日常改机器参数的第一落点。

## 主要文件

- `default.nix`：总入口
- `common.nix`：共享 registry 校验与 eval helper
- `x86_64-linux/default.nix`：NixOS 聚合、checks、apps
- `aarch64-darwin/default.nix`：Darwin 聚合、checks、apps

## 自动发现

- `nix/hosts/nixos/*` 需要 `hardware.nix`、`hardware-modules.nix`、`disko.nix`、`vars.nix`
- `nix/hosts/darwin/*` 需要 `default.nix`、`vars.nix`

## 当前导出面

- `nixosConfigurations`
- `darwinConfigurations`
- `homeConfigurations`
- `apps`
- `checks`
- `formatter`
- `packages`
- `overlays`
- `nixosModules`
- `devShells`

当前 `apps` 行为：

- Linux：仅保留 `install`
- Darwin：不导出 app

当前 `devShells` 行为：

- Linux：导出 `default` 与 `ml`
- `default` 提供 `just`、`check-jsonschema`、`shellcheck`、`shfmt`、`nixpkgs-fmt`、`statix`、`deadnix` 等本地维护工具
- `ml` 只覆盖主训练栈；`bitsandbytes`、`vLLM`、`llama.cpp` 不在默认 shell 中
- Darwin：不导出 dev shell

当前平台级 `checks`：

- `pre-commit-check`：构建并执行 pre-commit hooks
- `format-sanity`：执行 `nix/scripts/admin/check-format-sanity.sh`，覆盖 shell shebang、`.sops.yaml`、`justfile` 与 Nix 注释吞代码启发式检查

## 什么时候改这里

- 新增平台级 `apps` / `checks`
- 修改统一 registry 校验
- 增减对外复用导出面

如果只是新增主机、改某台机器参数或改 metadata，优先去：

- `nix/hosts/<platform>/<host>/`
- `nix/hosts/registry/systems.toml`
