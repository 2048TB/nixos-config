# hosts 目录

决定“每台机器用哪套配置”。

---

## 结构

```text
nix/hosts/
├── nixos/<host>/     # NixOS 主机
├── nixos/_shared/    # 共享模板（checks / disko / common workaround）
├── darwin/<host>/    # macOS 主机
├── registry/         # 主机注册表（systems.toml + schema）
└── outputs/          # flake 输出聚合（common.nix + platform outputs）
```

当前主机：NixOS `zly`、`zky`、`zzly` | Darwin `zly-mac`
当前主机清单与 metadata/deploy 信息以 `nix/hosts/registry/systems.toml` 为准。

`outputs/common.nix`：平台共享的 registry 校验与 eval-check 构造。

---

## 必需文件

**NixOS**：`hardware.nix` + `hardware-modules.nix` + `disko.nix` + `vars.nix`
**Darwin**：`default.nix` + `vars.nix`

可选：`home.nix`、`checks.nix`

说明：
- `checks.nix` 仅在该主机需要额外 eval 断言时才创建；通用 checks 已由 `nix/hosts/nixos/_shared/checks.nix` 统一装配
- host 目录优先只放 hardware、disk layout 与极少量 host-only workaround；通用行为优先进入 `nix/modules/core/` 或 `nix/home/`

---

## 新增主机

```bash
cp -a nix/hosts/nixos/zly nix/hosts/nixos/devbox
cp -a nix/hosts/darwin/zly-mac nix/hosts/darwin/mac-mini
```

新增后需编辑：
1. `vars.nix`：主机名、用户名、运行参数、roles（功能开关；含 `gpuMode` 与可选 `amdgpuBusId` / `nvidiaBusId`）
2. `disko.nix`：磁盘布局（NixOS；通常直接 import `_shared/disko-luks-btrfs.nix`）
3. `hardware-modules.nix`：显式列出该主机启用的 `nixos-hardware` 模块；CPU vendor 与纯 AMD 默认 `gpuMode` 从这里推导
4. `hardware.nix`：该主机的硬件入口；通常保持薄包装，只追加该机专属 import；若某个 workaround 完全共享且没有主机增量，也可直接 import `_shared/` 下的文件
5. `nix/hosts/registry/systems.toml`：新增该主机条目（`nixos.<host>` 或 `darwin.<host>`）
6. 模板中的旧主机名替换为新主机名（`rg -n 'zly|zly-mac' nix/hosts/<platform>/<new-host>`）

验证：优先使用直接 `nix eval` / `nix build`；若 repo 中存在不可读的 `.keys/main.agekey`，先通过 `nix/scripts/admin/print-flake-repo.sh` 获取 filtered repo 再做 read-only eval/build。

### 硬件层原则

- host metadata 流向：`nix/hosts/registry/systems.toml` -> `my.host` typed options -> `my.capabilities` -> modules
- `hardware-modules.nix` 是硬件事实入口：只放 `nixos-hardware` 模块名
- `hardware.nix` 通常是 `mylib.mkNixosHardwareModule` 的薄包装；helper 统一提供 initrd kernel module 车队基线、firmware 默认值与按 CPU vendor 收紧后的 microcode 默认值
- `hardware.nix` 当前同时承载少量设备服务基线（如 `bluetooth` / `fwupd`）；在没有明确收益前，不建议为了层次纯度拆得更碎
- `_shared/` 可以放跨主机复用的硬件模板或 common workaround；当前 NixOS 主机默认直接复用 `_shared/hardware-workarounds-common.nix`，机器专属问题仍留在主机目录
- Hybrid/NVIDIA 这类需要 bus ID 或额外约束的逻辑，放在主机目录下的显式拆分文件中

### registry 字段说明（`nix/hosts/registry/systems.toml`）

- `system`：平台（如 `x86_64-linux`、`aarch64-darwin`）
- `kind` / `formFactor`：host metadata 的基础分类，驱动 `my.capabilities.*`
- `desktopSession`：显式桌面会话开关，驱动 `my.capabilities.hasDesktopSession`
- `desktopProfile`：桌面 profile（当前 Linux 为 `niri`，Darwin 为 `aqua`）
- `tags`：规范化标签，仅保留无法稳定从其他 metadata 派生的事实；不要把 machine facts 再塞回 `roles`
- `gpuVendors`：声明式 GPU 厂商清单，用于 capability 推导
- `displays`：显示拓扑 metadata，驱动 Niri/Noctalia 等桌面配置生成，是 monitor facts 的唯一事实源
- `deployEnabled` / `deployHost` / `deployUser` / `deployPort`：仓库当前仅保留为 metadata，不再提供本地 deploy wrapper

注意：`outputs` 中已做双向断言，目录和 registry 任何一侧缺失都会直接 fail。

### 字段分组建议（统一分类）

- `Identity`：`hostname`、`username`、`timezone`
- `Platform`：`system`、`gpuMode`
- `Topology/Role`：`kind`、`formFactor`、`desktopSession`、`desktopProfile`、`displays` 表示机器拓扑与会话形态，`roles` 表示功能开关（如 `gaming` / `vpn` / `virt` / `container`）
- `Capability`：从 `kind` / `formFactor` / `gpuVendors` / `displays` / `tags` 派生，只读消费，不在主机目录手写；`multi-monitor` / `hidpi` 这类 display facts 不再通过 `tags` 表达
- `Deploy`：`deployEnabled`、`deployHost`、`deployUser`、`deployPort`（registry only）
- `Runtime`：`diskDevice`、`swapSizeGb`、`resumeOffset`

建议在 `vars.nix` 与 registry 保持同一分组顺序，减少跨文件跳读成本。

### GPU 字段说明（`vars.nix`）

- `gpuMode` 常见值：`modesetting`、`amdgpu`、`nvidia`、`amd-nvidia-hybrid`
- `amdgpuBusId` / `nvidiaBusId`：仅在 hybrid 场景需要，格式 `PCI:<bus>@<domain>:<device>:<function>`（十进制）
- 获取方式：`lspci -D` 后将槽位（如 `0000:12:00.0`）换算为 `PCI:18@0:0:0`

---

## 主机选择

当前保留的 `just install` 要求显式指定 `host=...`。
仓库已不再提供自动主机解析包装层。
显式传入的 repo 路径若无效，相关脚本会直接报错，不会静默回退。
