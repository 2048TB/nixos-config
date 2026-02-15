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
| `Ctrl + Alt + L` | 锁屏（swaylock） |
| `Super + Q` | 关闭当前窗口 |

## 焦点与窗口移动

| 快捷键 | 功能 |
|---|---|
| `Super + J/K` | 焦点切换（next/previous） |
| `Super + Shift + J/K` | 交换窗口（next/previous） |
| `Super + F` | 切换全屏 |
| `Super + V` | 切换浮动 |

## 多显示器

| 快捷键 | 功能 |
|---|---|
| `Super + .` | 聚焦下一个输出 |
| `Super + ,` | 聚焦上一个输出 |
| `Super + Shift + .` | 将窗口发送到下一个输出 |
| `Super + Shift + ,` | 将窗口发送到上一个输出 |

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

## 备注

- river 默认布局：`rivertile`。
- 若你后续改了 `nix/home/default.nix`，此文档应同步更新。
