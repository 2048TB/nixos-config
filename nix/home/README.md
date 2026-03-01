# nix/home 目录说明（新手版）

这里放的是 Home Manager 配置（用户级配置）。

如果你不知道改哪里，先看这条：
- 改系统级（服务、内核、磁盘）去 `nix/modules/` 或 `hosts/...`
- 改用户级（终端、主题、快捷键）来 `nix/home/`

---

## 1. 目录结构

- `nix/home/base/default.nix`：Linux + macOS 共享（session 变量、路径）
- `nix/home/linux/`：Linux 专用
  - `default.nix`：入口（session 变量、home.file、dconf）
  - `packages.nix`：home.packages + WPS 包装 + 独立脚本包
  - `programs.nix`：fzf/mpv/lutris/zsh/vim
  - `desktop.nix`：systemd 用户服务 + quiet launcher + waybar/swaybg
  - `xdg.nix`：xdg portal/mimeApps/configFile/userDirs
- `nix/home/darwin/default.nix`：macOS 专用
- `nix/home/configs/`：具体应用配置文件

常用子目录：
- `configs/niri/`：Niri
- `configs/waybar/`：Waybar
- `configs/shell/`：zsh/vim
- `configs/tmux/`：tmux
- `configs/zellij/`：zellij

---

## 2. 常见修改路径

- 改终端行为：`configs/shell/`、`configs/ghostty/`、`configs/foot/`
- 改桌面栏：`configs/waybar/`
- 改窗口快捷键：`configs/niri/keybindings.kdl`
- 改 tmux 快捷键：`configs/tmux/tmux.conf`

---

## 3. 修改后怎么生效

```bash
just switch
```

先检查再应用：

```bash
just check
just test
just switch
```

---

## 4. 排查（桌面/状态栏）

```bash
systemctl --user status waybar.service --no-pager
journalctl --user -b -u waybar.service -u xdg-desktop-portal.service --no-pager
```

---

## 5. 文档同步规则

如果你改了下面两个文件，记得同步更新 `KEYBINDINGS.md`：
- `nix/home/configs/tmux/tmux.conf`
- `nix/home/configs/zellij/config.kdl`
