# hosts 目录

决定“每台机器用哪套配置”。

---

## 结构

```text
nix/hosts/
├── nixos/<host>/     # NixOS 主机
├── nixos/_shared/    # 共享模板（hardware-common/disko-common/checks）
├── darwin/<host>/    # macOS 主机
├── registry/         # 主机注册表（systems.toml + schema）
└── outputs/          # flake 输出聚合（common.nix + platform outputs）
```

当前主机：NixOS `zly`、`zky`、`zzly` | Darwin `zly-mac`

`outputs/common.nix`：平台共享的 registry 校验、eval-check 构造与 strict host 解析模板。

---

## 必需文件

**NixOS**：`default.nix` + `hardware.nix` + `disko.nix` + `vars.nix`
**Darwin**：`default.nix` + `vars.nix`

可选：`home.nix`、`checks.nix`、`modules/`、`home-modules/`

说明：NixOS 的 `default.nix` 是薄入口，统一 import `hardware.nix` 与 `disko.nix`。

---

## 新增主机

```bash
cp -a nix/hosts/nixos/zly nix/hosts/nixos/devbox
cp -a nix/hosts/darwin/zly-mac nix/hosts/darwin/mac-mini
```

新增后需编辑：
1. `vars.nix`：主机名、用户名、硬件参数、roles（含 `gpuMode` 与可选 `intelBusId` / `amdgpuBusId` / `nvidiaBusId`）
2. `disko.nix`：磁盘布局（NixOS）
3. `hardware.nix`：硬件探测（NixOS）
4. `nix/hosts/registry/systems.toml`：新增该主机条目（`nixos.<host>` 或 `darwin.<host>`）
5. 模板中的旧主机名替换为新主机名（`rg -n 'zly|zly-mac' nix/hosts/<platform>/<new-host>`）

验证：`just hosts && just eval-tests && just host=devbox check`

### registry 字段说明（`nix/hosts/registry/systems.toml`）

- `system`：平台（如 `x86_64-linux`、`aarch64-darwin`）
- `formFactor`：`desktop` / `laptop` / `server`
- `profiles`：高层 profile 列表（驱动 `my.profiles.*`）
- `deployHost` / `deployUser`：远程部署目标（被 `deploy-hosts.sh` 使用）

注意：`outputs` 中已做双向断言，目录和 registry 任何一侧缺失都会直接 fail。

### 字段分组建议（统一分类）

- `Identity`：`hostname`、`username`、`timezone`
- `Platform`：`system`、`formFactor`、`cpuVendor`、`gpuMode`
- `Profile/Role`：`profiles`、`roles`
- `Deploy`：`deployHost`、`deployUser`
- `Runtime`：`diskDevice`、`swapSizeGb`、`resumeOffset`、各类 `enable*` 开关

建议在 `vars.nix` 与 registry 保持同一分组顺序，减少跨文件跳读成本。

### GPU 字段说明（`vars.nix`）

- `gpuMode` 常见值：`auto`、`modesetting`、`amd`、`nvidia`、`nvidia-prime`、`amd-nvidia-hybrid`
- `intelBusId` / `amdgpuBusId` / `nvidiaBusId`：仅在 Prime/Hybrid 场景需要，格式 `PCI:<bus>:<device>:<function>`（十进制）
- 获取方式：`lspci -D` 后将槽位（如 `0000:12:00.0`）换算为 `PCI:18:0:0`

---

## 主机解析

`resolve-host.sh` 的 strict 模式优先级：
1. `NIXOS_HOST` / `DARWIN_HOST` 环境变量
2. 当前 hostname

补充：当前 `justfile` 默认 `host := ""`，所以 `just switch/check/test` 未显式指定时会自动检测当前主机；跨主机操作建议显式指定 `host`。
