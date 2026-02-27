# 快捷键说明（Niri / Tmux / Zellij）

本文档对应以下配置文件（若文档与实际行为冲突，以配置文件为准）：
- `nix/home/configs/niri/keybindings.kdl`
- `nix/home/configs/tmux/tmux.conf`
- `nix/home/configs/zellij/config.kdl`

说明：`Mod` 在当前配置下等同 `Super`（Windows 键）。

## 应用启动与会话

| 快捷键 | 功能 |
|---|---|
| `Mod + Return` | 打开终端（Ghostty） |
| `Mod + Shift + Return` | 打开浮动终端（`ghostty-float`） |
| `Mod + Space` / `XF86Search` | 启动器（Fuzzel） |
| `Mod + D` | 文件管理器（Nautilus） |
| `Mod + Alt + L` | 锁屏（lock-screen -> swaylock） |
| `Mod + E` | 电源菜单（wlogout） |
| `Mod + Q` | 关闭当前窗口 |
| `Ctrl + Alt + Delete` | 退出 Niri（带确认） |

## 焦点与窗口移动

| 快捷键 | 功能 |
|---|---|
| `Mod + H/J/K/L` | 焦点切换（左/下/上/右） |
| `Mod + Left/Down/Up/Right` | 焦点切换（方向键别名） |
| `Mod + Ctrl + H/J/K/L` | 移动窗口/列 |
| `Mod + Ctrl + Left/Down/Up/Right` | 移动窗口/列（方向键别名） |
| `Mod + Alt + J/K` | 到达边界时继续跨工作区焦点切换（下/上） |
| `Mod + Alt + Ctrl + J/K` | 到达边界时将窗口移动到相邻工作区（下/上） |
| `Mod + Shift + H/J/K/L` | 切换显示器焦点 |
| `Mod + Shift + Ctrl + H/J/K/L` | 将列移动到相邻显示器 |
| `Mod + Alt + Shift + H/J/K/L` 或 `Left/Down/Up/Right` | 仅移动当前窗口到相邻显示器 |
| `Mod + Alt + Shift + Ctrl + H/J/K/L` 或 `Left/Down/Up/Right` | 将整个工作区移动到相邻显示器 |

## 工作区

| 快捷键 | 功能 |
|---|---|
| `Mod + U / I` | 切换到上/下一个工作区 |
| `Mod + Page_Down / Page_Up` | 切换到上/下一个工作区 |
| `Mod + Ctrl + U / I` | 将当前列移动到上/下一个工作区 |
| `Mod + Alt + U / I` | 将当前窗口移动到上/下一个工作区 |
| `Mod + B / N` | 将当前列快速投递到相邻工作区（Hyprland 习惯） |
| `Mod + 1..9` | 直达工作区 1..9 |
| `Mod + Ctrl + 1..9` | 将当前列移动到工作区 1..9 |
| `Mod + Alt + 1..9` | 将当前窗口移动到工作区 1..9 |
| `Mod + Tab` | 切换到上一个工作区 |
| `Mod + Shift + N` / `Mod + Ctrl + Shift + N` | 跳转到底部空工作区（新工作区） |

## 布局与尺寸

| 快捷键 | 功能 |
|---|---|
| `Mod + V` | 当前窗口浮动/平铺切换 |
| `Mod + G` | 在浮动/平铺窗口间切换焦点 |
| `Mod + W` | 切换列的 tabbed 显示 |
| `Mod + R` | 循环列宽预设 |
| `Mod + Shift + R` | 循环窗口高度预设 |
| `Mod + Ctrl + R` | 重置窗口高度 |
| `Mod + F` | 最大化当前列 |
| `Mod + Shift + F` | 全屏当前窗口 |
| `Mod + Shift + M` | 窗口最大化到屏幕边缘（非全屏） |
| `Mod + Z` | 最大化当前列（Hyprland 习惯别名） |
| `Mod + M` | 全屏当前窗口（Hyprland 习惯别名） |
| `Mod + Ctrl + F` | 列扩展到可用宽度 |
| `Mod + Alt + Space` / `Mod + Alt + Shift + Space` | 下一个/上一个键盘布局 |
| `Mod + Minus / Equal` | 列宽 -10% / +10% |
| `Mod + Shift + Minus / Equal` | 窗口高度 -10% / +10% |

## 滚轮操作（按住 Mod）

| 快捷键 | 功能 |
|---|---|
| `Mod + WheelScrollDown/Up` | 切换到上/下一个工作区（带 150ms 冷却） |
| `Mod + Ctrl + WheelScrollDown/Up` | 将当前列移动到上/下一个工作区（带 150ms 冷却） |
| `Mod + WheelScrollLeft/Right` | 焦点切换到左/右列 |
| `Mod + Ctrl + WheelScrollLeft/Right` | 将当前列移动到左/右 |

## 截图与剪贴板

| 快捷键 | 功能 |
|---|---|
| `Print` | 截图 |
| `Ctrl + Print` | 当前输出截图 |
| `Alt + Print` | 当前窗口截图 |
| `Mod + X` | 区域截图（保存文件并复制到剪贴板） |
| `Mod + Shift + V` | 剪贴板历史菜单（cliphist + fuzzel） |

## 媒体与亮度

| 按键 | 功能 |
|---|---|
| `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` | 音量 +1% / -1% |
| `XF86AudioMute` | 输出静音切换 |
| `XF86AudioMicMute` | 麦克风静音切换 |
| `XF86AudioPlay/Stop/Prev/Next` | 媒体播放控制 |
| `XF86MonBrightnessUp/Down` | 屏幕亮度 +1% / -1% |
| `XF86KbdBrightnessUp/Down` | 键盘背光 +10% / -10% |

## 其他

| 快捷键 | 功能 |
|---|---|
| `Mod + O` | 概览（workspace/window overview） |
| `Mod + Escape` | 切换 keyboard shortcuts inhibitor |
| `Mod + Shift + P` | 关闭显示器电源（任意输入唤醒） |
| `Mod + S` | 打开 `pavucontrol` |

## Tmux（Prefix: `Ctrl + B`）

| 快捷键 | 功能 |
|---|---|
| `Ctrl + B` | Prefix 键 |
| `Prefix + Ctrl + B` | 发送字面 `Ctrl + B` 到程序 |
| `Prefix + R` | 重载 `~/.config/tmux/tmux.conf` |
| `Prefix + H/J/K/L` 或 `Left/Down/Up/Right` | Pane 焦点切换（左/下/上/右） |
| `Prefix + V` / `Prefix + S` | 水平/垂直分屏（在当前路径） |
| `Prefix + Pipe` / `Prefix + -` | 水平/垂直分屏（经典别名） |
| `Prefix + X` | 关闭当前 Pane |
| `Prefix + Z` | 当前 Pane 放大/还原 |
| `Prefix + C` | 新建 Window |
| `Prefix + W` / `Prefix + Q` | 下一个/上一个 Window |
| `Prefix + Tab` | 切换到上一个活跃 Window（last-window） |
| `Prefix + P` | 显示 Pane 编号并快速选择（display-panes） |
| `Prefix + Shift + W` | 打开 Window/Session 树选择器（choose-tree） |
| `Prefix + G` | Detach 当前会话 |
| `Prefix + A/D/E/F` | 调整 Pane 大小（左/下/上/右，支持连按） |

## Zellij（Tmux Mode，Leader: `Ctrl + B`）

说明：
- 当前配置 `tmux clear-defaults=true`，只启用下表按键。
- 在 Normal mode 按 `Ctrl + B` 进入 Tmux mode；执行一次命令后自动回到 Normal mode。

| 快捷键 | 功能 |
|---|---|
| `Ctrl + B`（Normal） | 进入 Tmux mode |
| `Ctrl + B`（Tmux mode） | 发送字面 `Ctrl + B` 到 Pane，并返回 Normal mode |
| `Tmux mode + H/J/K/L` 或 `Left/Down/Up/Right` | Pane 焦点切换（左/下/上/右） |
| `Tmux mode + A/D/E/F` | 调整 Pane 大小（左/下/上/右） |
| `Tmux mode + S` / `V` | 向下/向右分屏 |
| `Tmux mode + X` | 关闭当前 Pane |
| `Tmux mode + Z` | 当前 Pane 全屏切换 |
| `Tmux mode + C` | 新建 Tab |
| `Tmux mode + W` / `Q` | 下一个/上一个 Tab |
| `Tmux mode + G` | Detach 当前会话 |
| `Tmux mode + R` | 切换到下一个布局（swap layout） |
