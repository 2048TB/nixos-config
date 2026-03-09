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
├── nix/
│   ├── lib/                   # Nix 库（mkNixosHost/mkDarwinHost/roleFlags/theme）
│   ├── hosts/                 # 主机配置
│   │   ├── nixos/<host>/      # NixOS（必须含 hardware.nix + disko.nix + vars.nix）
│   │   ├── darwin/<host>/     # macOS（必须含 default.nix + vars.nix）
│   │   ├── nixos/_shared/     # 共享模板
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
│       └── admin/             # 管理脚本（sops/install/resolve-host/guard-secrets/common）
├── secrets/                   # 加密 secrets（可提交）
├── wallpapers/                # 壁纸
├── docs/                      # 文档（README/KEYBINDINGS/NIX-COMMANDS/ENV-USAGE/...）
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
| 主机发现/脚手架/安装流程 | `docs/README.md`、`docs/NIX-COMMANDS.md`、`docs/ENV-USAGE.md` |
| justfile 命令或 flake apps | `docs/NIX-COMMANDS.md`、`docs/ENV-USAGE.md` |
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
# 文档改动
just eval-tests && just flake-check

# Nix 逻辑改动
just fmt && just lint

# Shell 脚本改动（仓库当前无 just scripts-check）
bash -n nix/scripts/admin/*.sh
```

---

## 6. 执行提醒

- 当前 `justfile` 默认 `host := ""`，执行 `just switch/check/test` 未显式指定时会自动解析当前主机；跨主机操作建议显式指定 `host=...`
- 当前 Linux/macOS 主账号的一致开发环境默认由 Home Manager 提供；system layer 保留桌面运行基线
- 未被要求时不主动推送；用户要求“同步到 GitHub”时才执行 Conventional Commit + `git push origin HEAD`
