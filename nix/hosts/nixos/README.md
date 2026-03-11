# NixOS 主机参数模板

此文件只整理“创建新 NixOS 主机配置所需的参数”。不包含软件安装开关、桌面应用开关或其他可选程序配置。

适用目录：`nix/hosts/nixos/<host>/`

通用目录组织、registry 规则与硬件层原则见 `nix/hosts/README.md`。

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
let
  common = import ../_shared/vars-common.nix;
in
common // {
  systemStateVersion = "25.11";
  homeStateVersion = "25.11";

  # Storage / Hibernate
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
    "vpn"
  ];
}
```

说明：`../_shared/vars-common.nix` 只放稳定共享默认值；`systemStateVersion`、`homeStateVersion`、`resumeOffset`、GPU 参数和角色列表仍建议在每台主机中显式定义。

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

说明：`hardware.nix` 通常保持薄包装；通用 initrd kernel modules、firmware 默认值以及按 CPU vendor 收紧后的 microcode 默认值由 helper 统一提供，主机只追加自己的 workaround 或 hybrid 模块。

如果该主机没有本地 workaround，且只想复用共享项，也可以直接 import `_shared/`：

```nix
args@{ mylib, ... }:
(mylib.mkNixosHardwareModule {
  extraImports = [ ../_shared/hardware-workarounds-common.nix ];
}) args
```

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
profiles = ["desktop"]
deployEnabled = true
deployHost = "<new-host>"
deployUser = "root"
deployPort = 22
```

## 实际数据入口

不要在 README 中抄写当前主机参数；以下文件才是事实源：

- 主机注册与 profile/deploy 信息：`nix/hosts/registry/systems.toml`
- 某台主机运行时参数：`nix/hosts/nixos/<host>/vars.nix`
- NixOS 主机共享默认值：`nix/hosts/nixos/_shared/vars-common.nix`
- 某台主机硬件模块清单：`nix/hosts/nixos/<host>/hardware-modules.nix`
- 某台主机额外硬件 import：`nix/hosts/nixos/<host>/hardware.nix`

---

## 磁盘布局共性

当前各台 NixOS 主机的 `disko.nix` 默认都直接 import `../_shared/disko-luks-btrfs.nix`，其共享布局为：

- GPT
- `ESP` 分区大小 `512M`
- 剩余空间为 `LUKS2`
- LUKS 内文件系统为 `btrfs`
- 子卷：`@root`、`@nix`、`@persistent`、`@home`、`@snapshots`、`@tmp`、`@swap`

如果新主机沿用现有布局，通常只需要重新确认：

- `diskDevice`
- `swapSizeGb`
- `resumeOffset`（仅在启用 hibernate 时需要）
