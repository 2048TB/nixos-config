# NixOS 主机参数模板

此文件只整理“创建新 NixOS 主机配置所需的参数”。不包含软件安装开关、桌面应用开关或其他可选程序配置。

适用目录：`nix/hosts/nixos/<host>/`

通用目录组织、registry 规则与硬件层原则见 `nix/hosts/README.md`。

---

## 当前 3 台主机

- `zky`
- `zly`
- `zzly`

---

## AI 创建新主机时需要产出的文件

1. `default.nix`
2. `vars.nix`
3. `hardware.nix`
4. `hardware-modules.nix`
5. `disko.nix`
6. `nix/hosts/registry/systems.toml` 中的新主机条目

其中：

- `default.nix` 当前三台主机完全一致，只 import `hardware.nix` 与 `disko.nix`
- `vars.nix` 是主参数入口
- `hardware-modules.nix` 决定 `nixos-hardware` 模块
- `hardware.nix` 决定该主机是否需要额外硬件 import
- `disko.nix` 决定磁盘布局

---

## 可直接复用的最小模板

### `default.nix`

```nix
{ ... }:
{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];
}
```

### `vars.nix`

```nix
{
  # Identity
  username = "z";
  timezone = "Asia/Shanghai";
  systemStateVersion = "25.11";
  homeStateVersion = "25.11";

  # Storage / Hibernate
  diskDevice =
    let
      envDiskDevice = builtins.getEnv "NIXOS_DISK_DEVICE";
    in
    if envDiskDevice != "" then envDiskDevice else "/dev/nvme0n1";
  swapSizeGb = 32;
  # Optional: set only when enabling hibernate with a btrfs swapfile.
  # resumeOffset = 1234567;

  # Hardware
  # CPU vendor is inferred from hardware-modules.nix.
  gpuMode = "amdgpu";   # or "nvidia" / "amd-nvidia-hybrid"

  # Only for hybrid GPU
  # amdgpuBusId = "PCI:18@0:0:0";
  # nvidiaBusId = "PCI:1@0:0:0";

  # Optional for NVIDIA / container setup
  # nvidiaOpen = true;
  # dockerMode = "rootless";

  # Roles
  roles = [
    "desktop"
    "vpn"
  ];
}
```

### `hardware-modules.nix`

```nix
[
  "common-pc"
  "common-pc-ssd"
  "common-cpu-amd"
]
```

### `hardware.nix`

```nix
args@{ mylib, ... }:
(mylib.mkNixosHardwareModule {
  extraImports = [ ./hardware-workarounds.nix ];
}) args
```

说明：`hardware.nix` 通常保持薄包装；通用 initrd / microcode 由 helper 统一提供，主机只追加自己的 workaround 或 hybrid 模块。

如果是 hybrid GPU 主机：

```nix
args@{ mylib, ... }:
(mylib.mkNixosHardwareModule {
  extraImports = [
    ./hardware-workarounds.nix
    ./hardware-gpu-hybrid.nix
  ];
}) args
```

### `systems.toml`

```toml
[nixos.<new-host>]
system = "x86_64-linux"
formFactor = "desktop"
profiles = ["desktop"]
deployEnabled = true
deployHost = "<new-host>"
deployUser = "root"
deployPort = 22
```

---

## 三台主机参数对照

### registry

| host | system | formFactor | profiles | deployEnabled | deployHost | deployUser | deployPort |
|---|---|---|---|---|---|---|---|
| `zky` | `x86_64-linux` | `laptop` | `["desktop", "laptop"]` | `true` | `zky` | `root` | `22` |
| `zly` | `x86_64-linux` | `desktop` | `["desktop"]` | `true` | `zly` | `root` | `22` |
| `zzly` | `x86_64-linux` | `desktop` | `["desktop"]` | `true` | `zzly` | `root` | `22` |

### `vars.nix`

| host | username | timezone | systemStateVersion | homeStateVersion | diskDevice | swapSizeGb | resumeOffset |
|---|---|---|---|---|---|---|---|
| `zky` | `z` | `Asia/Shanghai` | `25.11` | `25.11` | `/dev/nvme0n1` | `32` | `2990172` |
| `zly` | `z` | `Asia/Shanghai` | `25.11` | `25.11` | `/dev/nvme0n1` | `32` | `10113490` |
| `zzly` | `z` | `Asia/Shanghai` | `25.11` | `25.11` | `/dev/nvme0n1` | `32` | `1513128` |

### 硬件参数

| host | gpuMode | nvidiaOpen | dockerMode | amdgpuBusId | nvidiaBusId |
|---|---|---|---|---|---|
| `zky` | `nvidia` | `true` |  |  |  |
| `zly` | `amd-nvidia-hybrid` | `true` | `rootless` | `PCI:18@0:0:0` | `PCI:1@0:0:0` |
| `zzly` | `amdgpu` |  |  |  |  |

### roles

| host | roles |
|---|---|
| `zky` | `["desktop", "vpn"]` |
| `zly` | `["desktop", "gaming", "vpn", "virt", "container"]` |
| `zzly` | `["desktop", "vpn"]` |

### `hardware-modules.nix`

| host | modules |
|---|---|
| `zky` | `common-pc`, `common-pc-ssd`, `common-cpu-intel` |
| `zly` | `common-pc`, `common-pc-ssd`, `common-cpu-amd`, `common-gpu-amd` |
| `zzly` | `common-pc`, `common-pc-ssd`, `common-cpu-amd`, `common-gpu-amd` |

### `hardware.nix` 额外 import

| host | extraImports |
|---|---|
| `zky` | `hardware-workarounds.nix` |
| `zly` | `hardware-workarounds.nix`, `hardware-gpu-hybrid.nix` |
| `zzly` | `hardware-workarounds.nix` |

---

## 磁盘布局共性

三台主机的 `disko.nix` 当前一致：

- GPT
- `ESP` 分区大小 `512M`
- 剩余空间为 `LUKS2`
- LUKS 内文件系统为 `btrfs`
- 子卷：`@root`、`@nix`、`@persistent`、`@home`、`@snapshots`、`@tmp`、`@swap`

如果新主机沿用现有布局，通常只需要重新确认：

- `diskDevice`
- `swapSizeGb`
- `resumeOffset`（仅在启用 hibernate 时需要）
