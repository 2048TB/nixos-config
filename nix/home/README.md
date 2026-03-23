# home 目录

Home Manager 配置（用户级）。

- 改系统级（服务/内核/磁盘）→ `nix/modules/` 或 `nix/hosts/`
- 改用户级（终端/主题/快捷键）→ 本目录
- 主账号一致开发环境（语言/工具链）→ 优先放在 Home Manager
- Linux/Darwin 共享 CLI 包入口在 `nix/lib/default.nix` 的 `sharedPackageNames`
- 跨平台共享 config file 映射在 `nix/home/base/config-files.nix`
- Linux 侧入口通过 `_mixins` 统一收敛导入列表，新增 self-gating 模块时优先更新 allowlist

---

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
│   ├── desktop.nix     # 桌面用户服务与 Noctalia 包接入（udiskie/mullvad）
│   └── xdg.nix         # portal/mimeApps/configFile
├── darwin/default.nix  # macOS 专用
└── configs/            # 应用配置文件（niri/tmux/zellij/shell/television/...）
```

---

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

应用方式：当前仓库不再提供 `switch/check/test` 包装入口；修改本目录后，优先做 read-only flake eval/show，必要时再手动执行底层 NixOS/Home Manager 应用命令。
若 checkout 中存在不可读的 `.keys/main.agekey`，read-only flake eval/show 先通过 `nix/scripts/admin/print-flake-repo.sh` 获取 filtered repo。

---

## 文档同步

改了以下文件需同步 `docs/KEYBINDINGS.md`：
- `configs/niri/interaction.kdl`
- `configs/niri/appearance.kdl`
- `configs/tmux/tmux.conf`
- `configs/zellij/config.kdl`

改了以下文件通常不需要同步 `docs/KEYBINDINGS.md`，但建议补看 Home Manager 入口说明：
- `base/config-files.nix`
- `configs/shell/zshrc`
- `configs/television/*`
