# 快捷键说明（Hyprland）

本文档对应配置：`nix/home/default.nix` 中 `wayland.windowManager.hyprland.extraConfig`。
若文档与实际行为冲突，以 `nix/home/configs/hypr/hyprland.conf` 为准。

说明：`Super` 即 Windows 键。

## 应用启动与会话

| 快捷键 | 功能 |
|---|---|
| `Super + Return` | 打开终端（Ghostty） |
| `Super + Space` | 启动器（Fuzzel） |
| `Super + D` | 文件管理器（Nautilus） |
| `Super + S` | 切换 scratchpad 工作区 |
| `Super + Ctrl + C` | 剪贴板历史（cliphist + fuzzel） |
| `Super + Ctrl + S` | 打开音频面板（pavucontrol） |
| `Super + Ctrl + B` | 切换 Waybar 显示（SIGUSR1） |
| `Super + Ctrl + R` | 重载 Hyprland 配置 |
| `Super + Ctrl + E` | 电源菜单（wlogout） |
| `Super + Shift + E` | 退出 Hyprland 会话 |
| `Super + Shift + L` | 锁屏（hyprlock） |
| `Super + Shift + S` | 将当前窗口发送到 scratchpad |
| `Super + Q` | 关闭当前窗口 |

## 焦点、窗口交换与移动

| 快捷键 | 功能 |
|---|---|
| `Super + Left/Right/Up/Down` | 将窗口移动到对应方向（`movewindow`） |
| `Super + H/J/K/L` | 焦点切换（Vim 风格四向） |
| `Super + , / .` | 与左/右方向窗口交换（补齐四向） |
| `Super + Z` | 与主窗口交换（master） |
| `Super + F` | 切换全屏 |
| `Super + M` | 切换最大化（fullscreen mode 1） |
| `Super + V` | 切换浮动 |
| `Alt + Tab` | 循环切换窗口（浮动窗口会置顶） |

## 窗口移动与尺寸微调

| 快捷键 | 功能 |
|---|---|
| `Super + Ctrl + Shift + Left/Right/Up/Down` | 将窗口移动到方向位置（`movewindow`） |
| `Super + Home/End/PageUp/PageDown` | 将窗口移动到左/右/上/下（`movewindow` 双键别名） |
| `Super + Alt + H/J/K/L` | 微调当前窗口尺寸（`resizeactive`） |

## Master 布局控制

| 快捷键 | 功能 |
|---|---|
| `Super + Ctrl + Up/Down` | 增加/减少主区域比例（`mfact`） |
| `Super + Ctrl + Right/Left` | 增加/减少主区域窗口数（`addmaster/removemaster`） |
| `Super + Shift + Up/Right/Down/Left` | 设置主区域方向（top/right/bottom/left） |

## 浮动窗口控制（float submap）

| 快捷键 | 功能 |
|---|---|
| `Super + G` | 进入 `float` submap |
| `Left/Down/Up/Right`（float） | 移动浮动窗口 |
| `Shift + Left/Down/Up/Right`（float） | 调整浮动窗口大小 |
| `Ctrl + Left/Down/Up/Right`（float） | 快速移动浮动窗口 |
| `V`（float） | 切换浮动状态 |
| `Esc` / `Enter` / `Space`（float） | 返回 normal |

## 截图

| 快捷键 | 功能 |
|---|---|
| `Print` | 区域截图（保存文件并写入剪贴板） |
| `Super + X` | 区域截图（分体键盘友好别名） |

默认保存目录：`$XDG_SCREENSHOTS_DIR`，未设置时为 `~/Pictures/Screenshots`。

## 鼠标（指针）操作

| 快捷键 | 功能 |
|---|---|
| `Super + 鼠标左键拖动` | 移动窗口 |
| `Super + 鼠标右键拖动` | 调整窗口大小 |
| `Super + 鼠标中键` | 切换浮动 |
| `Super + 鼠标滚轮下/上` | 切换到下一个/上一个 workspace |
| `Super + Shift + 鼠标滚轮下/上` | 将当前窗口发送到下一个/上一个 workspace |

## Workspaces

| 快捷键 | 功能 |
|---|---|
| `Super + 1..9` | 切换到 workspace 1..9 |
| `Super + Shift + 1..9` | 将当前窗口移动到 workspace 1..9 |
| `Super + 0` | 切换到 workspace 10 |
| `Super + Shift + 0` | 将当前窗口移动到 workspace 10 |
| `Super + Alt + 1..9` | 将当前窗口静默发送到 workspace 1..9（不跟随切换） |
| `Super + Alt + 0` | 将当前窗口静默发送到 workspace 10（不跟随切换） |
| `Super + Alt + Right/Left` | 切换到下一个/上一个相对 workspace（`r+1/r-1`） |
| `Super + Alt + Down` | 跳转到第一个空 workspace（`empty`） |
| `Super + B / N` | 将当前窗口发送到上一个/下一个相对 workspace（`movetoworkspace r-1/r+1`） |
| `Super + Tab` | 切换到上一个 workspace |
| `Super + Shift + Tab` | 将当前窗口发送到上一个 workspace |

说明：`scratchpad` 使用 Hyprland special workspace（名称：`scratchpad`），可作为临时收纳区。

## 媒体与亮度

| 按键 | 功能 |
|---|---|
| `XF86AudioRaiseVolume` | 音量 +1% |
| `XF86AudioLowerVolume` | 音量 -1% |
| `XF86AudioMute` | 静音切换 |
| `XF86AudioMicMute` | 麦克风静音切换 |
| `XF86AudioPlay` / `XF86AudioPause` | 播放/暂停 |
| `XF86AudioNext` / `XF86AudioPrev` | 下一首/上一首 |
| `XF86MonBrightnessUp` / `XF86MonBrightnessDown` | 亮度 +5% / -5% |

## 模式切换（submap）

| 快捷键 | 功能 |
|---|---|
| `Super + P`（normal） | 进入 `passthrough` submap |
| `Super + P`（passthrough） | 返回 normal |
| `Esc`（passthrough） | 返回 normal（兜底） |

## 与 river 的差异

Hyprland 不支持 river 的 bitmask tags 工作流，因此下列语义不再存在：
- `Super + Alt + 1..9` 切换 tag 显示状态
- `Super + Ctrl + 1..9` 切换窗口多 tag 归属
- `Super + 0` 显示全部 tags（在 Hyprland 里改为 workspace 10）
