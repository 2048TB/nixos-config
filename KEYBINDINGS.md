# 快捷键说明

本文档覆盖 Hyprland + DMS、Ghostty、Tmux、Zellij、Foot 的按键配置。

说明：`Super` 即 Windows/GUI 键；`prefix` 指 Tmux 前缀键 `Ctrl+B`。

---

## Hyprland + DMS（窗口管理器 + 桌面 Shell）

配置文件：`nix/home/default.nix` → `wayland.windowManager.hyprland.extraConfig`

### 应用启动与 DMS 面板

| 快捷键 | 功能 |
|---|---|
| `Super + Return` | 打开终端（Ghostty） |
| `Super + T` | 打开终端（Ghostty） |
| `Super + Space` | DMS Spotlight 启动器 |
| `Super + D` | 打开 Nautilus |
| `Super + V` / `Super + Ctrl + C` | DMS 剪贴板 |
| `Super + M` | DMS 进程列表 |
| `Super + ,` | DMS 设置面板 |
| `Super + Y` | DMS 壁纸面板 |
| `Super + X` | DMS 电源菜单 |
| `Super + N` | DMS 通知中心 |
| `Super + Shift + N` / `Super + P` | DMS Notepad |
| `Super + Tab` | DMS Hypr Overview |
| `Super + Shift + /` | DMS Keybind Cheatsheet |
| `Super + Ctrl + E` | DMS 电源菜单（备用） |
| `Super + Alt + L` / `Super + Shift + L` | DMS 锁屏 |

### 窗口管理

| 快捷键 | 功能 |
|---|---|
| `Super + Q` | 关闭当前窗口 |
| `Super + Shift + E` | 退出 Hyprland 会话 |
| `Super + F` | 全屏（占满） |
| `Super + Shift + F` | 退出全屏 |
| `Super + Shift + T` | 切换浮动 |
| `Super + W` | 窗口分组 |
| `Super + H/J/K/L` 或 `Super + Arrow` | 焦点移动 |
| `Super + Shift + H/J/K/L` 或 `Super + Shift + Arrow` | 移动窗口 |
| `Super + Home/End` | 聚焦首/尾窗口 |
| `Super + Ctrl + H/J/K/L` | 切换显示器焦点 |
| `Super + Shift + Ctrl + H/J/K/L` | 窗口移动到其他显示器 |

### 工作区

| 快捷键 | 功能 |
|---|---|
| `Super + PageUp/PageDown` 或 `Super + U/I` | 在相邻工作区间切换 |
| `Super + 1..9` | 切换到工作区 1..9 |
| `Super + Ctrl + Up/Down` 或 `Super + Ctrl + U/I` | 移动窗口到相邻工作区 |
| `Super + Shift + PageUp/PageDown` 或 `Super + Shift + U/I` | 移动窗口并跟随到相邻工作区 |
| `Super + Shift + 1..9` | 将当前窗口移动到工作区 1..9 |
| `Super + Alt + 滚轮` | 在相邻工作区间切换 |
| `Super + Ctrl + Alt + 滚轮` | 移动窗口到相邻工作区 |

### 截图与鼠标

| 快捷键 | 功能 |
|---|---|
| `Print` | DMS 区域截图 |
| `Ctrl + Print` | DMS 全屏截图 |
| `Alt + Print` | DMS 当前窗口截图 |
| `Super + 鼠标左键拖拽` | 移动窗口 |
| `Super + 鼠标右键拖拽` | 调整窗口大小 |

### 媒体与亮度（DMS IPC）

| 按键 | 功能 |
|---|---|
| `XF86AudioRaiseVolume / LowerVolume` | 音量 ±3 |
| `XF86AudioMute` | 扬声器静音切换 |
| `XF86AudioMicMute` | 麦克风静音切换 |
| `XF86AudioPlay / Prev / Next` | MPRIS 播放控制 |
| `XF86MonBrightnessUp / Down` | 亮度 ±5 |

---

## Ghostty（终端）

配置文件：`nix/home/configs/ghostty/config`

### 复制粘贴

| 快捷键 | 功能 |
|---|---|
| `Ctrl + Shift + C` | 复制到剪贴板 |
| `Ctrl + Shift + V` | 从剪贴板粘贴 |

> `Ctrl + V` 已 unbind，保留给 Vim visual-block 和 Bash literal insert。

### 标签页

| 快捷键 | 功能 |
|---|---|
| `Ctrl + Shift + T` | 新建标签页 |
| `Ctrl + Shift + W` | 关闭标签页 |
| `Ctrl + Tab` | 下一个标签页 |
| `Ctrl + Shift + Tab` | 上一个标签页 |
| `Ctrl + 1..9` / `Alt + 1..9` | 跳转到指定标签页 |

### 窗口与显示

| 快捷键 | 功能 |
|---|---|
| `Ctrl + Shift + N` | 新建窗口 |
| `F11` | 切换全屏 |
| `Ctrl + Shift + K` / `Ctrl + L` | 清屏 |
| `Ctrl + = / +` | 字体放大 |
| `Ctrl + -` | 字体缩小 |
| `Ctrl + 0` | 字体重置 |

### 滚动

| 快捷键 | 功能 |
|---|---|
| `Shift + PageUp / PageDown` | 翻页滚动 |
| `Shift + Up / Down` | 逐行滚动 |

### 分屏（Ctrl+A leader）

| 快捷键 | 功能 |
|---|---|
| `Ctrl + A > Shift + 5` | 右侧分屏 |
| `Ctrl + A > Shift + '` | 下方分屏 |
| `Ctrl + A > x` | 关闭分屏 |
| `Ctrl + A > z` | 分屏缩放切换 |
| `Ctrl + A > h/j/k/l` | 分屏导航（Vim 风格） |
| `Alt + h/j/k/l` | 分屏导航（快捷方式） |
| `Ctrl + Shift + Arrow` | 调整分屏大小 |

### 其他

| 快捷键 | 功能 |
|---|---|
| `Ctrl + Shift + ,` | 重新加载配置 |

---

## Tmux（终端复用器）

配置文件：`nix/home/configs/tmux/tmux.conf`，前缀键：`Ctrl + B`

| 快捷键 | 功能 |
|---|---|
| `prefix + h/j/k/l` | Pane 导航（Vim 风格） |
| `prefix + \|` | 水平分割（保持当前路径） |
| `prefix + -` | 垂直分割（保持当前路径） |
| `prefix + H/J/K/L` | 调整 Pane 大小（可重复） |
| `prefix + r` | 重新加载配置 |

其余使用 Tmux 默认绑定。鼠标已启用。

---

## Zellij（终端复用器）

配置文件：`nix/home/configs/zellij/config.kdl`，使用默认按键绑定。

| 快捷键 | 功能 |
|---|---|
| `Ctrl + P` | 进入 Pane 模式（HJKL 导航） |
| `Ctrl + T` | 进入 Tab 模式 |
| `Ctrl + N` | 进入 Resize 模式 |
| `Ctrl + S` | 进入 Scroll 模式 |
| `Ctrl + O` | 进入 Session 模式 |
| `Ctrl + H` | 进入 Move 模式 |
| `Ctrl + G` | 锁定模式（按键直通终端） |

---

## Foot（终端）

配置文件：`nix/home/configs/foot/foot.ini`

| 快捷键 | 功能 |
|---|---|
| `Shift + Up` | 向上滚动一行 |
| `Shift + Down` | 向下滚动一行 |

其余使用 Foot 默认绑定。
