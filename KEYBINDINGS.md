# 快捷键说明

本文档覆盖 Hyprland + DMS、Ghostty、Tmux、Zellij、Foot 的按键配置。

说明：`Super` 即 Windows/GUI 键；`prefix` 指统一前缀 `Ctrl+A`（Tmux + Zellij 共用）。

---

## Hyprland + DMS（窗口管理器 + 桌面 Shell）

配置文件：`nix/home/default.nix` → `wayland.windowManager.hyprland.extraConfig`

### 应用启动与 DMS 面板

| 快捷键 | 功能 |
|---|---|
| `Super + Return` | 打开终端（Ghostty） |
| `Super + Space` | DMS Spotlight 启动器 |
| `Super + B` | 打开 Nautilus |
| `Super + V` | DMS 剪贴板 |
| `Super + M` | DMS 进程列表 |
| `Super + Shift + ,` | DMS 设置面板 |
| `Super + Shift + Y` | DMS 壁纸面板 |
| `Super + Shift + X` | DMS 电源菜单 |
| `Super + N` | DMS 通知中心 |
| `Super + Shift + N` | DMS Notepad |
| `Super + Tab` | DMS Hypr Overview |
| `Super + Shift + /` | DMS Keybind Cheatsheet |
| `Super + X` | DMS 锁屏 |

### 窗口管理

| 快捷键 | 功能 |
|---|---|
| `Super + Q` | 关闭当前窗口 |
| `Super + Shift + E` | 退出 Hyprland 会话 |
| `Super + F` | 全屏（占满） |
| `Super + Shift + F` | 退出全屏 |
| `Super + T` | 切换浮动 |
| `Super + G` | 窗口分组 |
| `Super + H/J/K/L` | 焦点移动 |
| `Super + Shift + H/J/K/L` 或 `Super + W/A/S/D` 或 `Super + Arrow` | 移动窗口 |
| `Super + Alt + H/J/K/L` 或 `Super + Alt + Arrow` | 与方向窗口交换位置 |
| `Super + [ / ]` | 与上一/下一窗口交换位置（顺序交换） |
| `Super + - / =`、`Super + ; / '` | 按方向缩放活动窗口 |
| `Super + Ctrl + F` | 重置活动窗口为 100% 尺寸 |
| `Super + Home/End` | 聚焦首/尾窗口 |
| `Super + Ctrl + H/J/K/L` | 切换显示器焦点 |
| `Super + Shift + Ctrl + H/J/K/L` | 窗口移动到其他显示器 |

### 工作区

| 快捷键 | 功能 |
|---|---|
| `Super + U/I` | 在相邻工作区间切换 |
| `Super + 1..9` | 切换到工作区 1..9 |
| `Super + Alt + Grave` | 切换 special workspace（scratchpad） |
| `Super + Shift + Grave` | 发送窗口到 special workspace（不跟随） |
| `Super + O/P` | 移动窗口到相邻工作区（并跟随） |
| `Super + , / .` | 静默发送窗口到相邻工作区（不切换） |
| `Super + F1..F9` | 将当前窗口移动到工作区 1..9（并跟随） |

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

## 分体键盘 Layer1（`2/1.vil`）

目标：`Layer0` 保持不变，`Layer1` 字母区按“左手结构、右手空间”分工，并优先按键复用与按键组合（宏仅保留兜底）。

| Layer1 键位语义 | 输出 |
|---|---|
| 左手 `F` | 专用 leader，发送 `Ctrl + A` |
| 左手 `Q/W/E/R/T` | leader 后第二击：`c/s/v/x/z`（新建/分屏/关闭/放大） |
| 左手 `A/S/D` | leader 后第二击：`r/d/n`（reload/detach/next） |
| 右手 `P` | leader 后第二击：`p`（prev） |
| 右手 `H/J/K/L` | leader 后第二击：`h/j/k/l`（pane 焦点） |
| 右手 `Y/U/I/O` | leader 后第二击：`y/u/i/o`（pane resize） |
| 左手 `Z/X/C/V` | `F13/F14/F15/F16`（映射到 Hyprland 跨显示器移动） |
| 直达补充 | `G=Super+N`，`B=Super+Q`，`M=Super+B`，`N=Super+M` |

## Tmux（终端复用器）

配置文件：`nix/home/configs/tmux/tmux.conf`，前缀键：`Ctrl + A`

| 快捷键 | 功能 |
|---|---|
| `prefix + h/j/k/l` | Pane 导航（Vim 风格） |
| `prefix + y/u/i/o` | 调整 Pane 大小（左/下/上/右，可重复） |
| `prefix + v/s` | 右/下分屏（保持当前路径） |
| `prefix + x/z` | 关闭 Pane / Pane 最大化切换 |
| `prefix + c` | 新建 window |
| `prefix + n/p` | 下一个/上一个 window |
| `prefix + C-a` | 发送字面 `Ctrl + A` 到程序 |
| `prefix + r` | 重新加载配置 |

其余使用 Tmux 默认绑定。鼠标已启用。

---

## Zellij（终端复用器）

配置文件：`nix/home/configs/zellij/config.kdl`，新增 Tmux 兼容层（共享 `Ctrl + A`），并对 `tmux` mode 启用 `clear-defaults` 防止重复按键。

| 快捷键 | 功能 |
|---|---|
| `Ctrl + A` | 进入 `Tmux` mode（与 tmux 前缀一致） |
| `Tmux mode + h/j/k/l` | Pane 焦点移动 |
| `Tmux mode + y/u/i/o` | Pane resize（左/下/上/右） |
| `Tmux mode + v/s` | 右/下分屏 |
| `Tmux mode + x/z` | 关闭 pane / pane 全屏切换 |
| `Tmux mode + c` | 新建 tab |
| `Tmux mode + n/p` | 下一个/上一个 tab |
| `Tmux mode + d` | detach session |
| `Tmux mode + r` | 切换到下一套 layout |

---

## Foot（终端）

配置文件：`nix/home/configs/foot/foot.ini`

| 快捷键 | 功能 |
|---|---|
| `Shift + Up` | 向上滚动一行 |
| `Shift + Down` | 向下滚动一行 |

其余使用 Foot 默认绑定。
