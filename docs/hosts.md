# Host Matrix

> Generated from `nix/registry/systems.toml` and `nix/hosts/*/*/vars.nix`. Do not edit manually.

当前主机能力矩阵，方便快速查看每台机器的 `roles`、系统层 `software`、用户层 `homeSoftware` 与关键差异。

其中：
- `languageTools` 表示 Home Manager 补充语言工具模块
- `roles` 表示系统功能角色
- `formFactor` 只表示主机形态

| Host | Platform | System | Roles | System software | Home software | Notes | Source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `zky` | `NixOS laptop` | `x86_64-linux` | `desktop, vpn` | `none` | `archive, browser, chat, cli, desktopCore, dev, media, remote` | cpu=intel; gpu=nvidia; deploy=root@zky | `nix/hosts/nixos/zky/vars.nix` |
| `zly` | `NixOS desktop` | `x86_64-linux` | `desktop, vpn, virt, container` | `dive, dockerCompose, lazydocker, virtManager, virtViewer` | `archive, browser, chat, cli, desktopCore, dev, media, remote` | cpu=amd; gpu=amd-nvidia-hybrid; docker=rootless; deploy=root@zly | `nix/hosts/nixos/zly/vars.nix` |
| `zzly` | `NixOS desktop` | `x86_64-linux` | `desktop, vpn` | `none` | `browser, cli, desktopCore, dev, remote` | cpu=amd; gpu=amd; deploy=root@zzly | `nix/hosts/nixos/zzly/vars.nix` |
| `mbp-work` | `Darwin laptop` | `aarch64-darwin` | `none` | `none` | `cli` | deploy=z@mbp-work | `nix/hosts/darwin/mbp-work/vars.nix` |

## Host Notes

### `zky`

- `cpuVendor = "intel"`
- `gpuMode = "nvidia"`
- `formFactor = "laptop"`
- `roles = [ "desktop", "vpn" ]`
- `deploy = "root@zky"`
- 来源：`nix/hosts/nixos/zky/vars.nix`

### `zly`

- `cpuVendor = "amd"`
- `gpuMode = "amd-nvidia-hybrid"`
- `dockerMode = "rootless"`
- `formFactor = "desktop"`
- `roles = [ "desktop", "vpn", "virt", "container" ]`
- `deploy = "root@zly"`
- 来源：`nix/hosts/nixos/zly/vars.nix`

### `zzly`

- `cpuVendor = "amd"`
- `gpuMode = "amd"`
- `formFactor = "desktop"`
- `roles = [ "desktop", "vpn" ]`
- `deploy = "root@zzly"`
- 来源：`nix/hosts/nixos/zzly/vars.nix`

### `mbp-work`

- `formFactor = "laptop"`
- `roles = [  ]`
- `deploy = "z@mbp-work"`
- 来源：`nix/hosts/darwin/mbp-work/vars.nix`
