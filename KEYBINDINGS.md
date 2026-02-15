# 快捷键说明（river-classic）

本文档对应配置：`nix/home/default.nix` 中 `wayland.windowManager.river.extraConfig`。

说明：`Super` 即 Windows 键。

## 应用启动与会话

| 快捷键 | 功能 |
|---|---|
| `Super + Return` | 打开终端（Ghostty） |
| `Super + Space` | 启动器（Fuzzel） |
| `Super + D` | 文件管理器（Nautilus） |
| `Super + Ctrl + C` | 剪贴板历史（cliphist + fuzzel） |
| `Super + Ctrl + S` | 打开音频面板（pavucontrol） |
| `Super + Ctrl + E` | 电源菜单（wlogout） |
| `Super + Shift + E` | 退出 river 会话 |
| `Super + Shift + L` | 锁屏（swaylock） |
| `Super + Q` | 关闭当前窗口 |

## 焦点与窗口交换

| 快捷键 | 功能 |
|---|---|
| `Super + Left/Right` | 焦点切换（previous/next，仅平铺窗口） |
| `Super + Up/Down` | 交换窗口（previous/next） |
| `Super + Z` | 将当前窗口提升到栈顶（zoom） |
| `Super + F` | 切换全屏 |
| `Super + V` | 切换浮动 |

## rivertile 布局控制

| 快捷键 | 功能 |
|---|---|
| `Super + Ctrl + Up/Down` | 增加/减少主区域比例（main-ratio） |
| `Super + Ctrl + Right/Left` | 增加/减少主区域窗口数（main-count） |
| `Super + Shift + Up/Right/Down/Left` | 设置主区域方向（top/right/bottom/left） |

## 浮动窗口控制（float 模式）

| 快捷键 | 功能 |
|---|---|
| `Super + G` | 进入 `float` 模式 |
| `Left/Down/Up/Right`（float 模式） | 移动浮动窗口 |
| `Shift + Left/Down/Up/Right`（float 模式） | 调整浮动窗口大小 |
| `Ctrl + Left/Down/Up/Right`（float 模式） | 将浮动窗口吸附到边缘 |
| `V`（float 模式） | 切换浮动状态 |
| `Esc` / `Enter` / `Space`（float 模式） | 返回 normal 模式 |

## 截图（新增）

| 快捷键 | 功能 |
|---|---|
| `Print` | 区域截图（保存文件并写入剪贴板） |
| `Super + X` | 区域截图（分体键盘友好别名） |

默认保存目录：`$XDG_SCREENSHOTS_DIR`，未设置时为 `~/Pictures/Screenshots`。

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
| `Super + Alt + 1..9` | 切换对应 tag 显示状态 |
| `Super + Ctrl + 1..9` | 切换当前窗口在对应 tag 的状态 |
| `Super + 0` | 显示全部 tags |
| `Super + Shift + 0` | 当前窗口加入全部 tags |
| `Super + Tab` | 切换到上一个 tags 组合 |
| `Super + Shift + Tab` | 将当前窗口发送到上一个 tags 组合 |

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
| `Esc`（passthrough） | 返回 `normal` 模式（兜底） |
