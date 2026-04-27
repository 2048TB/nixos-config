# hosts 目录

本目录决定“有哪些主机”和“每台主机的最小 host-only 参数”。全仓库通用行为与流程仍以 `docs/README.md` 为准。

## 结构

```text
nix/hosts/
├── nixos/<host>/     # NixOS 主机
├── nixos/_shared/    # 共享模板、checks、workarounds
├── darwin/<host>/    # macOS 主机
├── registry/         # host metadata 事实源
└── outputs/          # flake 输出聚合
```

当前主机清单与 metadata 统一以 `nix/hosts/registry/systems.toml` 为准。

## 事实源

- host metadata：`nix/hosts/registry/systems.toml`
- NixOS 主机模板：`nix/hosts/nixos/README.md`
- flake outputs 聚合：`nix/hosts/outputs/README.md`

## 什么时候改这里

- 新增/删除主机
- 修改某台主机的 `vars.nix`
- 修改 host-only 硬件导入、`disko`、resume、bus ID
- 变更 registry metadata，例如 `displays`、`kind`、`gpuVendors`

如果改的是通用模块、role 逻辑、桌面行为或 Home Manager，优先去：

- `nix/modules/core/`
- `nix/home/`
- `nix/lib/`

## NixOS 主机最小文件集

- `hardware.nix`
- `hardware-modules.nix`
- `disko.nix`
- `vars.nix`

可选：

- `home.nix`
- `checks.nix`

`vars.nix` 可按 host 覆盖 `configRepoPath`；未设置时默认使用 `/persistent/nixos-config`。

Darwin 主机最小文件集：

- `default.nix`
- `vars.nix`

## 新增主机

```bash
cp -a nix/hosts/nixos/zly nix/hosts/nixos/devbox
cp -a nix/hosts/darwin/zly-mac nix/hosts/darwin/mac-mini
```

至少同步这些位置：

1. `nix/hosts/<platform>/<host>/vars.nix`
2. `nix/hosts/<platform>/<host>/hardware*.nix`
3. `nix/hosts/<platform>/<host>/disko.nix`（NixOS）
4. `nix/hosts/registry/systems.toml`

新增后建议：

```bash
rg -n 'zly|zly-mac' nix/hosts/<platform>/<new-host>
```

## Host Metadata 约束

- `roles` 是功能开关，不是 machine topology 容器
- `vpn` role 当前表示 Mullvad app / daemon 集成，不再表示仓库内 WireGuard profile catalog
- `tags` 只保留无法稳定派生的事实
- `displays` 是 monitor topology 的唯一事实源
- `desktopProfile` 当前 Linux 只支持 `niri`
- `gpuMode` 当前值为 `none` / `modesetting` / `amdgpu` / `nvidia` / `amd-nvidia-hybrid`
- `displays.primary` 必须是 `bool`
- `displays.match` 必须是 `string` 或 `null`
- 声明 `displays` 时必须且只能有一个 `primary = true`
- `gpuVendors` 必须与 `gpuMode` 匹配；hybrid 模式还必须有 `amdgpuBusId` / `nvidiaBusId`
- `gaming` role 必须搭配 `desktopSession = true`

## 验证

read-only 验证优先用 filtered repo：

```bash
REPO=/persistent/nixos-config
flake_repo="$(bash "$REPO/nix/scripts/admin/print-flake-repo.sh" "$REPO")"
nix eval "path:$flake_repo#nixosConfigurations" --apply builtins.attrNames
```

改动 `nix/hosts/registry/*` 或 host metadata 后，至少补跑：

```bash
just self-check
just registry-schema-check
just registry-meta-sync-check
just flake-check
```

命令细节与系统级流程见 `docs/README.md`。
