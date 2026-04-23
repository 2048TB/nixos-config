# home 目录

本目录承载用户级配置。全仓库流程与脚本行为见 `docs/README.md`；这里只描述 Home Manager 结构与常见落点。

## 结构

```text
nix/home/
├── base/default.nix    # 跨平台共享（session 变量、PATH、mise shims、zsh/vim）
├── base/config-files.nix # 跨平台 configFile 映射清单
├── linux/
│   ├── default.nix     # 入口（identity、imports、dconf、assertions）
│   ├── _mixins/default.nix # Linux 模块 auto-import allowlist
│   ├── session.nix     # Linux session vars、activation
│   ├── files.nix       # repo link / wallpapers / user-level dotfiles / GUI wrapper
│   ├── packages.nix    # home.packages（含主账号开发环境）
│   ├── package-groups.nix # Linux 包分类清单（纯数据）
│   ├── programs.nix    # fzf/mpv/lutris 等
│   ├── desktop.nix     # 桌面用户服务、fcitx/kwm-status/swayidle、Nautilus override、mise-upgrade
│   └── xdg.nix         # portal/mimeApps/configFile
├── darwin/default.nix  # macOS 专用
└── configs/            # 应用配置文件（kwm/tmux/zellij/shell/television/...）
```

## 常见修改

| 目标 | 文件 |
|------|------|
| 终端 | `configs/ghostty/`、`configs/foot/`、`configs/shell/` |
| 共享 CLI 包 | `../lib/default.nix`（`sharedPackageNames`） |
| 跨平台 config file 映射 | `base/config-files.nix` |
| GUI IDE wrapper | `linux/files.nix` |
| Television | `configs/television/` + `base/config-files.nix` + `configs/shell/zshrc` |
| 状态栏 | `configs/kwm/config.zon` + `linux/desktop.nix`（kwm 内置 bar + status writer） |
| 窗口快捷键 | `configs/kwm/config.zon` |
| 窗口外观 | `configs/kwm/config.zon` |
| 壁纸 | `linux/files.nix` + `linux/desktop.nix` + `configs/river/wallpaper.sh` |
| River 会话脚本 | `configs/river/` + `linux/xdg.nix` |
| 锁屏 / idle | `linux/desktop.nix` + `configs/river/` |
| 输入法 profile / 默认激活 | `configs/fcitx5/` + `linux/session.nix` + `linux/desktop.nix` |
| Linux 包分类 | `linux/package-groups.nix` |
| Tmux | `configs/tmux/tmux.conf` |
| Zellij | `configs/zellij/config.kdl` |

额外约束：

- Linux/Darwin 共享 CLI 包入口在 `nix/lib/default.nix` 的 `sharedPackageNames`
- 跨平台共享 config file 映射在 `nix/home/base/config-files.nix`
- `base/default.nix` 当前会把 `~/.local/share/mise/shims` 放进 session `PATH`
- `linux/session.nix` 只放通用 GUI/input session vars；CUDA/OpenSSL 工具链变量收敛到 devShell
- `configs/mise/config.toml` 当前默认将全局 `python` 固定在 `3.12`，其余常用工具继续跟随 rolling channel
- Linux 侧入口通过 `_mixins` allowlist 收敛导入列表
- `linux/xdg.nix` 当前会生成 `~/.config/river/outputs.sh`，来源是 host registry `displays` metadata
- `linux/files.nix` 当前还负责 `~/.local/bin/code` 与 `~/.local/bin/antigravity` wrapper：前置 `mise` shims，并过滤已知 Electron Wayland 参数告警
- `linux/desktop.nix` 当前还负责 `mise-upgrade.service`；`mise-upgrade.timer` 只有 host 显式设置 `my.host.miseAutoUpgrade = true` 时才安装

read-only 验证时，若 checkout 中存在不可读的 `.keys/main.agekey`，先通过 `nix/scripts/admin/print-flake-repo.sh` 获取 filtered repo。

涉及 Home Manager 行为改动后，建议至少执行：

```bash
just validate-local
```

## 文档同步

改了以下文件需同步 `docs/KEYBINDINGS.md`：
- `configs/kwm/config.zon`
- `configs/river/lock.sh`
- `configs/river/screenshot.sh`
- `configs/tmux/tmux.conf`
- `configs/zellij/config.kdl`

改了以下文件通常不需要同步 `docs/KEYBINDINGS.md`：

- `base/config-files.nix`
- `configs/shell/zshrc`
- `configs/television/*`
