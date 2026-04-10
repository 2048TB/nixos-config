# home 目录

本目录承载用户级配置。全仓库流程与脚本行为见 `docs/README.md`；这里只描述 Home Manager 结构与常见落点。

## 结构

```text
nix/home/
├── base/default.nix    # 跨平台共享（session 变量、PATH、zsh/vim）
├── base/config-files.nix # 跨平台 configFile 映射清单
├── linux/
│   ├── default.nix     # 入口（identity、imports、dconf、assertions）
│   ├── _mixins/default.nix # Linux 模块 auto-import allowlist
│   ├── session.nix     # Linux session vars、activation
│   ├── files.nix       # repo link / wallpapers / user-level dotfiles
│   ├── packages.nix    # home.packages（含主账号开发环境）
│   ├── package-groups.nix # Linux 包分类清单（纯数据）
│   ├── programs.nix    # fzf/mpv/lutris 等
│   ├── desktop.nix     # 桌面用户服务与 Noctalia 包接入（udiskie/provider-app）
│   └── xdg.nix         # portal/mimeApps/configFile
├── darwin/default.nix  # macOS 专用
└── configs/            # 应用配置文件（niri/tmux/zellij/shell/television/...）
```

## 常见修改

| 目标 | 文件 |
|------|------|
| 终端 | `configs/ghostty/`、`configs/foot/`、`configs/shell/` |
| 共享 CLI 包 | `../lib/default.nix`（`sharedPackageNames`） |
| 跨平台 config file 映射 | `base/config-files.nix` |
| Television | `configs/television/` + `base/config-files.nix` + `configs/shell/zshrc` |
| 状态栏 | `configs/niri/config.kdl`（Noctalia autostart） + `linux/desktop.nix`（包接入） |
| 窗口快捷键 | `configs/niri/interaction.kdl` + `configs/niri/appearance.kdl` |
| 窗口外观 | `configs/niri/appearance.kdl` |
| Linux 包分类 | `linux/package-groups.nix` |
| Tmux | `configs/tmux/tmux.conf` |
| Zellij | `configs/zellij/config.kdl` |

额外约束：

- Linux/Darwin 共享 CLI 包入口在 `nix/lib/default.nix` 的 `sharedPackageNames`
- 跨平台共享 config file 映射在 `nix/home/base/config-files.nix`
- Linux 侧入口通过 `_mixins` allowlist 收敛导入列表
- `nix/home/configs/noctalia/` 当前按设计直接映射到 repo 工作树；GUI 改动会直接修改 tracked files

read-only 验证时，若 checkout 中存在不可读的 `.keys/main.agekey`，先通过 `nix/scripts/admin/print-flake-repo.sh` 获取 filtered repo。

涉及 Home Manager 行为改动后，建议至少执行：

```bash
just validate-local
```

## 文档同步

改了以下文件需同步 `docs/KEYBINDINGS.md`：
- `configs/niri/interaction.kdl`
- `configs/niri/appearance.kdl`
- `configs/tmux/tmux.conf`
- `configs/zellij/config.kdl`

改了以下文件通常不需要同步 `docs/KEYBINDINGS.md`：

- `base/config-files.nix`
- `configs/shell/zshrc`
- `configs/television/*`
