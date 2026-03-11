# Architecture

仓库采用 flake-based 多主机分层：

- `flake.nix` 只声明 inputs，并把 outputs 委托给 `nix/hosts/outputs/`
- `nix/hosts/outputs/` 负责主机发现、registry 校验、`apps/checks/devShells` 聚合
- `nix/lib/mkNixosHost.nix` 与 `nix/lib/mkDarwinHost.nix` 负责把 registry、host vars、system/home modules 组装成最终主机
- `nix/modules/` 放 system-level 基线与 role/profile 逻辑
- `nix/home/` 放 Home Manager 用户层配置
- `nix/hosts/<platform>/<host>/` 只保留主机特有参数、硬件入口，以及少数确有例外时才需要的 host-local checks
- NixOS 硬件装配默认由 `mylib.mkNixosHardwareModule` 提供 initrd kernel module 车队基线、firmware 默认值与按 CPU vendor 收紧后的 microcode 默认值；当前主机默认直接复用 `_shared/hardware-workarounds-common.nix`

设计原则：

- 共享逻辑优先收敛到 `nix/lib/`、`nix/modules/`、`nix/home/`
- 主机目录保持显式入口，不为了 DRY 隐藏硬件差异
- host eval checks 默认走 shared 装配，仅在主机需要额外断言时再添加本地 `checks.nix`
- registry 只保留真实消费的主机元数据，避免文档和运行时双重事实源

相关入口：

- 文档总览：`docs/README.md`
- 主机结构：`nix/hosts/README.md`
- Home Manager 结构：`nix/home/README.md`
