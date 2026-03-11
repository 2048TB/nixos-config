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

`outputs/common.nix`：平台共享的 registry 校验、eval-check 构造与 strict host 解析模板。

---

## 必需文件

**NixOS**：`default.nix` + `hardware.nix` + `hardware-modules.nix` + `disko.nix` + `vars.nix`
**Darwin**：`default.nix` + `vars.nix`

可选：`home.nix`、`checks.nix`

说明：NixOS 的 `default.nix` 是薄入口，统一 import `hardware.nix` 与 `disko.nix`。

---

## 新增主机

```bash
cp -a nix/hosts/nixos/zly nix/hosts/nixos/devbox
cp -a nix/hosts/darwin/zly-mac nix/hosts/darwin/mac-mini
```

新增后需编辑：
1. `vars.nix`：主机名、用户名、硬件参数、roles（含 `gpuMode` 与可选 `amdgpuBusId` / `nvidiaBusId`）
2. `disko.nix`：磁盘布局（NixOS；通常直接 import `_shared/disko-luks-btrfs.nix`）
3. `hardware-modules.nix`：显式列出该主机启用的 `nixos-hardware` 模块；CPU vendor 与纯 AMD 默认 `gpuMode` 从这里推导
4. `hardware.nix`：该主机的硬件入口；通常保持薄包装，只追加该机专属 import
5. `nix/hosts/registry/systems.toml`：新增该主机条目（`nixos.<host>` 或 `darwin.<host>`）
6. 模板中的旧主机名替换为新主机名（`rg -n 'zly|zly-mac' nix/hosts/<platform>/<new-host>`）

验证：`just hosts && just eval-tests && just host=devbox check`

### 硬件层原则

- `hardware-modules.nix` 是硬件事实入口：只放 `nixos-hardware` 模块名
- `hardware.nix` 通常是 `mylib.mkNixosHardwareModule` 的薄包装；主机特有硬件项放在本机拆分文件中
- `_shared/` 可以放跨主机复用的硬件模板或 common workaround；机器专属问题仍留在主机目录
- Hybrid/NVIDIA 这类需要 bus ID 或额外约束的逻辑，放在主机目录下的显式拆分文件中

### registry 字段说明（`nix/hosts/registry/systems.toml`）

- `system`：平台（如 `x86_64-linux`、`aarch64-darwin`）
- `formFactor`：`desktop` / `laptop` / `server`
- `profiles`：高层 profile 列表（驱动 `my.profiles.*`）
- `deployEnabled`：是否允许被 `deploy-hosts.sh` 批量部署
- `deployHost` / `deployUser` / `deployPort`：远程部署目标（仅 registry 使用；`deploy-hosts.sh` 直接读取）

注意：`outputs` 中已做双向断言，目录和 registry 任何一侧缺失都会直接 fail。

### 字段分组建议（统一分类）

- `Identity`：`hostname`、`username`、`timezone`
- `Platform`：`system`、`formFactor`、`gpuMode`
- `Profile/Role`：`profiles`、`roles`
- `Deploy`：`deployEnabled`、`deployHost`、`deployUser`、`deployPort`（registry only）
- `Runtime`：`diskDevice`、`swapSizeGb`、`resumeOffset`

建议在 `vars.nix` 与 registry 保持同一分组顺序，减少跨文件跳读成本。

### GPU 字段说明（`vars.nix`）

- `gpuMode` 常见值：`auto`、`modesetting`、`amdgpu`、`nvidia`、`amd-nvidia-hybrid`
- `amdgpuBusId` / `nvidiaBusId`：仅在 hybrid 场景需要，格式 `PCI:<bus>@<domain>:<device>:<function>`（十进制）
- 获取方式：`lspci -D` 后将槽位（如 `0000:12:00.0`）换算为 `PCI:18@0:0:0`

---

## 主机解析

`resolve-host.sh` 的 strict 模式优先级：
1. `NIXOS_HOST` / `DARWIN_HOST` 环境变量
2. 当前 hostname

补充：当前 `justfile` 默认 `host := ""`，所以 `just switch/check/test` 未显式指定时会自动检测当前主机；跨主机操作建议显式指定 `host`。
