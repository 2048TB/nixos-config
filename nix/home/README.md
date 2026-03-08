# home 目录

Home Manager 配置（用户级）。

- 改系统级（服务/内核/磁盘）→ `nix/modules/` 或 `nix/hosts/`
- 改用户级（终端/主题/快捷键）→ 本目录

---

## 结构

```
nix/home/
├── base/default.nix    # 跨平台共享（session 变量、PATH、zsh/vim）
├── linux/
│   ├── default.nix     # 入口（session vars、home.file、dconf）
│   ├── packages.nix    # home.packages + 脚本包
│   ├── programs.nix    # fzf/mpv/lutris
│   ├── desktop.nix     # systemd 用户服务（noctalia-shell/udiskie/mullvad）
│   └── xdg.nix         # portal/mimeApps/configFile
├── darwin/default.nix  # macOS 专用
└── configs/            # 应用配置文件
    ├── niri/           # 窗口管理器
    ├── shell/          # zsh/vim
    ├── tmux/           # tmux
    ├── zellij/         # zellij
    ├── ghostty/        # 终端
    ├── foot/           # 备用终端
    ├── fuzzel/         # 启动器
    └── ...
```

---

## 常见修改

| 目标 | 文件 |
|------|------|
| 终端 | `configs/ghostty/`、`configs/foot/`、`configs/shell/` |
| 状态栏 | `linux/desktop.nix`（noctalia-shell service） |
| 窗口快捷键 | `configs/niri/interaction.kdl` |
| 窗口外观 | `configs/niri/appearance.kdl` |
| Tmux | `configs/tmux/tmux.conf` |

改完后 `just switch` 生效。

---

## 文档同步

改了以下文件需同步 `docs/KEYBINDINGS.md`：
- `configs/niri/interaction.kdl`
- `configs/tmux/tmux.conf`
- `configs/zellij/config.kdl`
