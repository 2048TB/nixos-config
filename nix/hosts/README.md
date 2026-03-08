# hosts 目录

决定"每台机器用哪套配置"。

---

## 结构

```
nix/hosts/
├── nixos/<host>/     # NixOS 主机
├── nixos/_shared/    # 共享模板（hardware-common/disko-common/checks）
├── darwin/<host>/    # macOS 主机
└── outputs/          # flake 输出聚合
```

当前主机：NixOS `zly`、`zky`、`zzly` | Darwin `zly-mac`

---

## 必需文件

**NixOS**：`hardware.nix` + `disko.nix` + `vars.nix`
**Darwin**：`default.nix` + `vars.nix`

可选：`home.nix`、`checks.nix`、`modules/`、`home-modules/`

---

## 新增主机

```bash
cp -a nix/hosts/nixos/zly nix/hosts/nixos/devbox
cp -a nix/hosts/darwin/zly-mac nix/hosts/darwin/mac-mini
```

新增后需编辑：
1. `vars.nix` — 主机名、用户名、硬件参数、roles（含 `gpuMode` 与可选 `intelBusId` / `amdgpuBusId` / `nvidiaBusId`）
2. `disko.nix` — 磁盘布局
3. `hardware.nix` — 硬件探测
4. 将模板中的旧主机名替换为新主机名（`rg -n 'zly|zly-mac' nix/hosts/<platform>/<new-host>`）

验证：`just hosts && just eval-tests && just host=devbox check`

### GPU 字段说明（`vars.nix`）

- `gpuMode` 常见值：`auto`、`modesetting`、`amd`、`nvidia`、`nvidia-prime`、`amd-nvidia-hybrid`
- `intelBusId` / `amdgpuBusId` / `nvidiaBusId`：仅在 Prime/Hybrid 场景需要，格式为 `PCI:<bus>:<device>:<function>`（十进制）
- 获取方式：`lspci -D` 后将槽位（如 `0000:12:00.0`）换算为 `PCI:18:0:0`

---

## 主机自动检测

`just switch` 等命令不指定 `host` 时自动检测（strict 模式）：
1. `NIXOS_HOST` / `DARWIN_HOST` 环境变量
2. 当前 hostname

不匹配时报错，不 fallback。安装命令必须显式指定。
