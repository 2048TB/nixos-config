# 快捷键说明（Hyprland / Tmux / Zellij）

本文档对应以下配置文件（若文档与实际行为冲突，以配置文件为准）：
- `nix/home/configs/hypr/hyprland.conf`
- `nix/home/configs/tmux/tmux.conf`
- `nix/home/configs/zellij/config.kdl`

说明：`Super` 即 Windows 键。

## 应用启动与会话

| 快捷键 | 功能 
|---|---|
| `Super + Return` | 打开终端（Ghostty） |
| `Super + Space` | 启动器（Fuzzel） |
| `Super + Q` | 关闭当前窗口 |
| `Super + E` | 文件管理器（Nautilus） |
| `Super + T` | 切换布局模式（`master`/`scrolling`） |
| `Super + W` | Pin 当前窗口到所有工作区（仅 floating 窗口有效） |
| `Super + Ctrl + C` | 剪贴板历史（cliphist + fuzzel） |
| `Super + Ctrl + S` | 打开音频面板（pavucontrol） |
| `Super + Ctrl + B` | 切换 Waybar 显示（SIGUSR1） |
| `Super + Ctrl + R` | 重载 Hyprland 配置 |
| `Super + Ctrl + E` | 电源菜单（wlogout） |
| `Super + Shift + E` | 退出 Hyprland 会话 |
| `Super + Shift + L` | 锁屏（hyprlock） |
| `Super + Shift + B` | 切换 scratchpad 工作区 |
| `Super + Shift + T` | 将当前窗口发送到 scratchpad |

## 焦点、窗口交换与移动

| 快捷键 | 功能 |
|---|---|
| `Super + Left/Right/Up/Down` | 将窗口移动到对应方向（`movewindow`） |
| `Super + H/J/K/L` | 焦点切换（Vim 风格四向） |
| `Super + S / D` | 与左/右方向窗口交换（补齐四向） |
| `Super + Shift + Alt + H/J/K/L` | 切换显示器焦点（`focusmonitor`） |
| `Super + C` | 切换全屏 |
| `Super + F` | 当前布局主操作（master: 与主窗口交换 / scrolling: 聚焦列适配） |
| `Super + Z` | 切换最大化（fullscreen mode 1） |
| `Super + X` | 切换浮动 |
| `Alt + Tab` | 循环切换窗口（浮动窗口会置顶） |

## 窗口移动与尺寸微调

| 快捷键 | 功能 |
|---|---|
| `Super + Ctrl + Shift + Left/Right/Up/Down` | 将窗口移动到方向位置（`movewindow`） |
| `Super + Home/End/PageUp/PageDown` | 将窗口移动到左/右/上/下（`movewindow` 双键别名） |
| `Super + Ctrl + H/J/K/L` | 将当前窗口发送到左/下/上/右显示器（`movewindow mon:*`） |
| `Super + Ctrl + Shift + H/J/K/L` | 将当前工作区发送到左/下/上/右显示器（`movecurrentworkspacetomonitor`） |
| `Super + Alt + H/J/K/L` | 微调当前窗口尺寸（`resizeactive`） |

## 布局控制（Master / Scrolling）

| 快捷键 | 功能 |
|---|---|
| `Super + Ctrl + Up/Down` | 主参数增减（master: `mfact ±0.05` / scrolling: `colresize ±0.05`） |
| `Super + Ctrl + Right/Left` | 结构前进/后退（master: `addmaster/removemaster` / scrolling: `move ±col`） |
| `Super + Shift + Up/Down` | 上/下扩展操作（master: `orientationtop/bottom` / scrolling: `colresize ±conf`） |
| `Super + Shift + Right/Left` | 右/左扩展操作（master: `orientationright/left` / scrolling: `swapcol r/l`） |

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
| `Super + A` | 区域截图（分体键盘友好别名） |

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

## Tmux（Prefix: `Ctrl + B`）

| 快捷键 | 功能 |
|---|---|
| `Ctrl + B` | Prefix 键 |
| `Prefix + Ctrl + B` | 发送字面 `Ctrl + B` 到程序 |
| `Prefix + R` | 重载 `~/.config/tmux/tmux.conf` |
| `Prefix + Left/Down/Up/Right` | Pane 焦点切换（左/下/上/右） |
| `Prefix + W` / `Prefix + E` | 水平/垂直分屏（在当前路径） |
| `Prefix + Q` | 关闭当前 Pane |
| `Prefix + Z` | 当前 Pane 放大/还原 |
| `Prefix + C` | 新建 Window |
| `Prefix + D` / `Prefix + S` | 下一个/上一个 Window |
| `Prefix + Tab` | 切换到上一个活跃 Window（last-window） |
| `Prefix + T` | 显示 Pane 编号并快速选择（display-panes） |
| `Prefix + Shift + F` | 打开 Window/Session 树选择器（choose-tree） |
| `Prefix + G` | Detach 当前会话 |
| `Prefix + H/J/K/L` | 调整 Pane 大小（左/下/上/右，支持连按） |

## Zellij（Tmux Mode，Leader: `Ctrl + B`）

说明：
- 当前配置 `tmux clear-defaults=true`，只启用下表按键。
- 在 Normal mode 按 `Ctrl + B` 进入 Tmux mode；执行一次命令后自动回到 Normal mode。
- 其中 `T` / `Shift + F` / `R` 为 Zellij 下的近似语义映射（分别对应 `TogglePaneFrames`、`session-manager`、`configuration`）。

| 快捷键 | 功能 |
|---|---|
| `Ctrl + B`（Normal） | 进入 Tmux mode |
| `Ctrl + B`（Tmux mode） | 发送字面 `Ctrl + B` 到 Pane，并返回 Normal mode |
| `Tmux mode + Left/Down/Up/Right` | Pane 焦点切换（左/下/上/右） |
| `Tmux mode + H/J/K/L` | 调整 Pane 大小（左/下/上/右） |
| `Tmux mode + W` / `E` | 向右/向下分屏 |
| `Tmux mode + Q` | 关闭当前 Pane |
| `Tmux mode + Z` | 当前 Pane 全屏切换 |
| `Tmux mode + C` | 新建 Tab |
| `Tmux mode + D` / `S` | 下一个/上一个 Tab |
| `Tmux mode + Tab` | 切换到上一个活跃 Tab（ToggleTab） |
| `Tmux mode + T` | 切换 Pane 边框显示（近似 `display-panes`） |
| `Tmux mode + Shift + F` | 打开会话/Tab 管理器（session-manager，近似 `choose-tree`） |
| `Tmux mode + R` | 打开配置面板（configuration，近似 `reload config`） |
| `Tmux mode + G` | Detach 当前会话 |
