# CLAUDE.md

AI/自动化工具专用。目标：高效完成用户请求，不破坏仓库稳定性。

---

## 1. 工作边界

- 只做用户明确要求的改动，默认最小 diff
- 不做无关重构，中文说明，技术名词可用 English

---

## 2. 仓库结构

```text
nixos-config/
├── flake.nix                  # 入口
├── .github/
│   ├── actions/setup-nix/     # CI 复用步骤
│   └── workflows/             # lock checker / cleanup
├── nix/
│   ├── lib/                   # Nix 库（mkNixosHost/mkDarwinHost/roleFlags/theme）
│   ├── hosts/                 # 主机配置
│   │   ├── nixos/<host>/      # NixOS（必须含 hardware.nix + hardware-modules.nix + disko.nix + vars.nix）
│   │   ├── darwin/<host>/     # macOS（必须含 default.nix + vars.nix）
│   │   ├── nixos/_shared/     # 共享 checks / disko 模板 / 通用 workaround
│   │   ├── registry/          # 主机注册表（systems.toml + schema）
│   │   └── outputs/           # flake 输出聚合
│   ├── modules/
│   │   ├── core/              # NixOS 系统模块（boot/services/desktop/security/storage/hardware）
│   │   └── darwin/            # macOS 系统模块
│   ├── home/
│   │   ├── base/              # 跨平台共享（session 变量 + PATH）
│   │   ├── linux/             # Linux HM（default/packages/programs/desktop/xdg；含主账号开发环境）
│   │   ├── darwin/            # macOS HM
│   │   └── configs/           # 应用配置文件（niri/tmux/zellij/shell...）
│   └── scripts/
│       └── admin/             # 保留脚本（install/print-flake-repo/update-flake/sops/guard-secrets/common）
├── secrets/                   # 加密 secrets（可提交）
├── wallpapers/                # 壁纸
├── docs/                      # 文档（README/ENV-USAGE/NIX-COMMANDS/KEYBINDINGS/...）
├── justfile                   # 命令入口
├── CLAUDE.md                  # 本文件
└── AGENTS.md                  # 贡献者指南
```

## 3. 文档同步规则

| 改动范围 | 需同步的文档 |
|----------|-------------|
| 快捷键（Niri/Tmux/Zellij） | `docs/KEYBINDINGS.md` |
| 主机发现/脚手架/安装流程 | `README.md`、`docs/README.md`、`docs/NIX-COMMANDS.md`、`docs/ENV-USAGE.md` |
| hosts/hardware/disko/registry 布局 | `nix/hosts/README.md`、`nix/hosts/nixos/README.md`、必要时 `docs/ENV-USAGE.md` |
| justfile 命令或 flake apps | `docs/NIX-COMMANDS.md`、`docs/ENV-USAGE.md` |
| CI / workflow / 最小脚本入口 | `docs/README.md`、必要时 `CLAUDE.md` / `AGENTS.md` |
| 流程规则 | `CLAUDE.md`、`AGENTS.md` |

---

## 4. 安全规则

- 禁止提交私钥、token、明文密码
- `secrets/*.yaml` 可提交，`.keys/*.agekey` 不可提交
- 安装与分区（disko）命令视为危险操作
- 密码来源：sops（`secrets/passwords/*.yaml`），不使用明文文件

---

## 5. 验证要求

```bash
# 保留的 read-only 检查入口
just info
bash nix/scripts/admin/print-flake-repo.sh .

# 保留的脚本自检入口
bash -n nix/scripts/admin/*.sh
bash nix/scripts/admin/guard-secrets.sh
```

---

## 6. Host Metadata 模型

- host metadata 的事实源是 `nix/hosts/registry/systems.toml`
- registry 当前承载：`system`、`kind`、`formFactor`、`desktopSession`、`desktopProfile`、`tags`、`gpuVendors`、`displays`、`deployEnabled`、`deployHost`、`deployUser`、`deployPort`
- 模块消费路径固定为：`registry -> my.host` typed options -> `my.capabilities`
- Linux NixOS/Home Manager 入口默认走 auto-discovered `_mixins`
- `roles` 仍保留为功能开关；不要重新引入旧 `profiles` host 模型，也不要把 machine topology 塞进 `roles`
- `tags` 只保留无法稳定派生的事实；`multi-monitor` / `hidpi` 这类 display facts 不再手写
- 不要在桌面配置里硬编码 monitor 名称；优先从 registry `displays` metadata 生成
- Linux `desktopProfile` 当前只支持 `niri`；Darwin 使用 `aqua`
- `gpuMode` 当前正式值为 `none` / `modesetting` / `amdgpu` / `nvidia` / `amd-nvidia-hybrid`，不要再写 `auto`

---

## 7. 执行提醒

- 当前 `justfile` 只保留最小入口；安装时必须显式指定 `host=...`
- 当前 Linux/macOS 主账号的一致开发环境默认由 Home Manager 提供；system layer 保留桌面运行基线
- 当前 NixOS 主机默认直接 import `nix/hosts/nixos/_shared/hardware-workarounds-common.nix`；host-local `hardware-workarounds.nix` 仅在确有主机专属例外时才保留
- 当前仓库仅保留 `nix/scripts/admin/*.sh`；不再保留 `repo-check`、`flake-check`、`eval-tests`、`rebuild-*`、`deploy` 包装层
- 对 read-only flake eval/build/check，优先走 `just` 或 `nix/scripts/admin/*.sh`；当前脚本会在 `.keys/main.agekey` 不可读时自动切到 filtered flake repo
- 未被要求时不主动推送；用户要求“同步到 GitHub”时才执行 Conventional Commit + `git push origin HEAD`
