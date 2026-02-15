# 快捷键说明（river-classic）

本文档基于当前配置：`nix/home/default.nix` 中 `wayland.windowManager.river.extraConfig`。

说明：`Super` 即 Windows 键。

## 应用启动与会话

| 快捷键 | 功能 |
|---|---|
| `Super + Return` | 打开终端（Ghostty） |
| `Super + Space` | 启动器（Fuzzel） |
| `Super + D` | 文件管理器（Nautilus） |
| `Super + E` | 电源菜单（wlogout） |
| `Super + Shift + E` | 退出 river 会话 |
| `Ctrl + Alt + L` | 锁屏（swaylock） |
| `Super + Q` | 关闭当前窗口 |

## 焦点与窗口栈

| 快捷键 | 功能 |
|---|---|
| `Super + J/K` | 焦点切换（next/previous） |
| `Super + Shift + J/K` | 交换窗口（next/previous） |
| `Super + Z` | 将当前窗口提升到栈顶（zoom） |
| `Super + F` | 切换全屏 |
| `Super + V` | 切换浮动 |

## 多显示器

| 快捷键 | 功能 |
|---|---|
| `Super + .` | 聚焦下一个输出 |
| `Super + ,` | 聚焦上一个输出 |
| `Super + Shift + .` | 将窗口发送到下一个输出 |
| `Super + Shift + ,` | 将窗口发送到上一个输出 |

## rivertile 布局控制

| 快捷键 | 功能 |
|---|---|
| `Super + H/L` | 减少/增加主区域比例（main-ratio） |
| `Super + Shift + H/L` | 增加/减少主区域窗口数（main-count） |
| `Super + Ctrl + K/L/J/H` | 设置主区域方向（top/right/bottom/left） |

## 浮动窗口控制

| 快捷键 | 功能 |
|---|---|
| `Super + Alt + H/J/K/L` | 移动浮动窗口 |
| `Super + Alt + Shift + H/J/K/L` | 调整浮动窗口大小 |
| `Super + Alt + Ctrl + H/J/K/L` | 将浮动窗口吸附到边缘 |

## 鼠标（指针）操作

| 快捷键 | 功能 |
|---|---|
| `Super + 鼠标左键拖动` | 移动窗口（move-view） |
| `Super + 鼠标右键拖动` | 调整窗口大小（resize-view） |
| `Super + 鼠标中键` | 切换浮动（toggle-float） |

## Tags（dwm 风格）

| 快捷键 | 功能 |
|---|---|
| `Super + 1..9` | 查看对应 tag |
| `Super + Shift + 1..9` | 将当前窗口设置到对应 tag |
| `Super + Ctrl + 1..9` | 切换对应 tag 显示状态 |
| `Super + Shift + Ctrl + 1..9` | 切换当前窗口在对应 tag 的状态 |
| `Super + 0` | 显示全部 tags |
| `Super + Shift + 0` | 当前窗口加入全部 tags |

## 媒体与亮度（normal/locked）

| 按键 | 功能 |
|---|---|
| `XF86AudioRaiseVolume` | 音量 +1% |
| `XF86AudioLowerVolume` | 音量 -1% |
| `XF86AudioMute` | 静音切换 |
| `XF86AudioMicMute` | 麦克风静音切换 |
| `XF86AudioPlay` | 播放/暂停 |
| `XF86AudioPrev` | 上一曲 |
| `XF86AudioNext` | 下一曲 |
| `XF86MonBrightnessUp` | 亮度 +1% |
| `XF86MonBrightnessDown` | 亮度 -1% |

## 模式切换

| 快捷键 | 功能 |
|---|---|
| `Super + P`（normal） | 进入 `passthrough` 模式 |
| `Super + P`（passthrough） | 返回 `normal` 模式 |

## 备注

- river 默认布局：`rivertile`。
- 已移除 `F1-F12` 相关绑定。
- 与官方示例差异：保留 `Super + Return` 打开终端，因此将 `zoom` 绑定为 `Super + Z`。
- 若你后续改了 `nix/home/default.nix`，此文档应同步更新。
