# 快捷键说明（Niri）

本文档对应配置：`nix/home/configs/niri/keybindings.kdl`。
若文档与实际行为冲突，以该文件为准。

说明：`Mod` 在当前配置下等同 `Super`（Windows 键）。

## 应用启动与会话

| 快捷键 | 功能 |
|---|---|
| `Mod + Return` | 打开终端（Ghostty） |
| `Mod + Shift + Return` | 打开浮动终端（`ghostty-float`） |
| `Mod + Space` / `XF86Search` | 启动器（Fuzzel） |
| `Mod + D` | 文件管理器（Nautilus） |
| `Mod + Shift + L` | 锁屏（lock-screen -> swaylock） |
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
| `Mod + Shift + H/J/K` | 切换显示器焦点 |
| `Mod + Shift + Ctrl + H/J/K/L` | 将列移动到相邻显示器 |

## 工作区

| 快捷键 | 功能 |
|---|---|
| `Mod + U / I` | 切换到上/下一个工作区 |
| `Mod + Page_Down / Page_Up` | 切换到上/下一个工作区 |
| `Mod + Ctrl + U / I` | 将当前列移动到上/下一个工作区 |
| `Mod + X / Z` | 将当前列快速投递到相邻工作区 |
| `Mod + 1..9` | 直达工作区 1..9 |
| `Mod + Ctrl + 1..9` | 将当前列移动到工作区 1..9 |
| `Mod + Tab` | 切换到上一个工作区 |
| `Mod + N` / `Mod + Shift + N` | 跳转到底部空工作区（新工作区） |

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
| `Mod + Ctrl + F` | 列扩展到可用宽度 |
| `Mod + Minus / Equal` | 列宽 -10% / +10% |
| `Mod + Shift + Minus / Equal` | 窗口高度 -10% / +10% |

## 截图与剪贴板

| 快捷键 | 功能 |
|---|---|
| `Print` | 截图 |
| `Ctrl + Print` | 当前输出截图 |
| `Alt + Print` | 当前窗口截图 |
| `Mod + A` | 区域截图（保存文件并复制到剪贴板） |
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
