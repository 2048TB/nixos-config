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
just new-nixos-host devbox          # 从 zly 模板复制
just new-darwin-host mac-mini       # 从 zly-mac 模板复制
just new-nixos-host-dry-run devbox  # 预览
```

新增后需编辑：
1. `vars.nix` — 主机名、用户名、硬件参数、roles
2. `disko.nix` — 磁盘布局
3. `hardware.nix` — 硬件探测

验证：`just hosts && just eval-tests && just host=devbox check`

---

## 主机自动检测

`just switch` 等命令不指定 `host` 时自动检测（strict 模式）：
1. `NIXOS_HOST` / `DARWIN_HOST` 环境变量
2. 当前 hostname

不匹配时报错，不 fallback。安装命令必须显式指定。
