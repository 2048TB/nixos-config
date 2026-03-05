# CLAUDE.md

AI/自动化工具专用。目标：高效完成用户请求，不破坏仓库稳定性。

---

## 1. 工作边界

- 只做用户明确要求的改动，默认最小 diff
- 不做无关重构，中文说明，技术名词可用英文

---

## 2. 仓库结构

```
nixos-config/
├── flake.nix                  # 入口
├── nix/
│   ├── lib/                   # Nix 库（mkNixosHost/mkDarwinHost/roleFlags/theme）
│   ├── hosts/                 # 主机配置
│   │   ├── nixos/<host>/      # NixOS（必须含 hardware.nix + disko.nix + vars.nix）
│   │   ├── darwin/<host>/     # macOS（必须含 default.nix + vars.nix）
│   │   ├── nixos/_shared/     # 共享模板
│   │   └── outputs/           # flake 输出聚合（自动发现，无需注册）
│   ├── modules/
│   │   ├── core/              # NixOS 系统模块（boot/services/desktop/security/storage）
│   │   ├── darwin/            # macOS 系统模块
│   │   └── hardware.nix       # GPU/蓝牙/固件
│   ├── home/
│   │   ├── base/              # 跨平台共享（session 变量 + PATH）
│   │   ├── linux/             # Linux HM（default/packages/programs/desktop/xdg）
│   │   ├── darwin/            # macOS HM
│   │   └── configs/           # 应用配置文件（niri/waybar/shell/tmux/zellij…）
│   └── scripts/
│       ├── admin/             # 管理脚本（agenix/install/resolve-host/new-host/guard-secrets）
│       └── session/           # 会话脚本（waybar/lock-screen/screenshot/wlogout…）
├── secrets/                   # 加密 secrets（可提交）
├── secrets.nix                # agenix recipients
├── wallpapers/                # 壁纸
├── docs/                      # 文档（README/KEYBINDINGS/NIX-COMMANDS/ENV-USAGE）
├── justfile                   # 命令入口
├── CLAUDE.md                  # 本文件
└── AGENTS.md                  # 贡献者指南
```

主题系统：`nix/lib/theme.nix`（Nord 调色板，单一来源）
- 内联引用：`mytheme.palette.<color>.hex` / `.rgb`
- 模板替换：`mytheme.apply` + `@THEME_<COLOR>@` 占位符

---

## 3. 文档同步规则

| 改动范围 | 需同步的文档 |
|----------|-------------|
| 快捷键（Niri/Tmux/Zellij） | `docs/KEYBINDINGS.md` |
| 主机发现/脚手架/安装流程 | `docs/README.md`、`docs/NIX-COMMANDS.md` |
| justfile 命令或 flake apps | `docs/NIX-COMMANDS.md`、`docs/ENV-USAGE.md` |
| 流程规则 | `CLAUDE.md`、`AGENTS.md` |

---

## 4. 安全规则

- 禁止提交私钥、token、明文密码
- `secrets/*.age` 可提交，`.keys/*.agekey` 不可提交
- 安装与分区（disko）命令视为危险操作
- 密码来源：agenix（`secrets/passwords/*.age`），不使用明文文件

---

## 5. 验证要求

```bash
# 文档改动
just eval-tests && just flake-check

# Nix 逻辑改动
just fmt && just lint

# Shell 脚本改动
just scripts-check
```

---

## 6. Git 规则

- 用户要求"同步到 GitHub"时：Conventional Commit + `git push origin HEAD`
- 未被要求时不主动推送
