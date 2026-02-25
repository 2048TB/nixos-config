# 快捷键说明

本文档覆盖 River、Ghostty、Tmux、Zellij、Foot 的按键配置。

说明：`Super` 即 Windows/GUI 键；`prefix` 指 Tmux 前缀键 `Ctrl+B`。

---

## River（窗口管理器）

配置文件：`nix/home/default.nix` → `wayland.windowManager.river.extraConfig`

### 应用启动与会话

| 快捷键 | 功能 |
|---|---|
| `Super + Return` | 打开终端（Ghostty） |
| `Super + Space` | 启动器（Fuzzel） |
| `Super + D` | 文件管理器（Nautilus） |
| `Super + Q` | 关闭当前窗口 |
| `Super + Ctrl + C` | 剪贴板历史（cliphist + fuzzel） |
| `Super + Ctrl + S` | 音频面板（pavucontrol） |
| `Super + Ctrl + E` | 电源菜单（wlogout） |
| `Super + Shift + E` | 退出 river 会话 |
| `Super + Shift + L` | 锁屏（gtklock） |

### 焦点与窗口交换

| 快捷键 | 功能 |
|---|---|
| `Super + Left/Right` | 焦点切换（previous/next） |
| `Super + H/L` | 焦点切换（Vim 风格） |
| `Super + Down/Up` | 交换窗口位置 |
| `Super + J/K` | 交换窗口位置（Vim 风格） |
| `Super + Z` | 当前窗口提升到栈顶（zoom） |
| `Super + F` | 切换全屏 |
| `Super + V` | 切换浮动 |

### rivertile 布局控制

| 快捷键 | 功能 |
|---|---|
| `Super + Ctrl + Up/K` | 增加主区域比例（main-ratio） |
| `Super + Ctrl + Down/J` | 减少主区域比例 |
| `Super + Ctrl + Right/L` | 增加主区域窗口数（main-count） |
| `Super + Ctrl + Left/H` | 减少主区域窗口数 |
| `Super + Shift + Up/Down/Left/Right` | 设置主区域方向 |

### 浮动窗口控制（float 模式）

| 快捷键 | 功能 |
|---|---|
| `Super + G` | 进入 float 模式 |
| `Arrow / H/J/K/L` | 移动浮动窗口 |
| `Shift + Arrow / H/J/K/L` | 调整浮动窗口大小 |
| `Ctrl + Arrow / H/J/K/L` | 吸附到边缘 |
| `V` | 切换浮动状态 |
| `Esc / Enter / Space` | 返回 normal 模式 |

### 截图

| 快捷键 | 功能 |
|---|---|
| `Print` | 区域截图（保存文件并写入剪贴板） |
| `Super + X` | 区域截图（分体键盘友好） |

### 鼠标操作

| 快捷键 | 功能 |
|---|---|
| `Super + 鼠标左键` | 移动窗口 |
| `Super + 鼠标右键` | 调整窗口大小 |
| `Super + 鼠标中键` | 切换浮动 |

### Tags（dwm 风格）

| 快捷键 | 功能 |
|---|---|
| `Super + 1..9` | 查看对应 tag |
| `Super + Shift + 1..9` | 当前窗口移到对应 tag |
| `Super + Alt + 1..9` | 切换 tag 显示状态 |
| `Super + Ctrl + 1..9` | 切换窗口在 tag 的状态 |
| `Super + 0` | 显示全部 tags |
| `Super + Shift + 0` | 当前窗口加入全部 tags |
| `Super + Tab` | 切换到上一个 tags 组合 |
| `Super + Shift + Tab` | 当前窗口发送到上一个 tags |

### 模式切换

| 快捷键 | 功能 |
|---|---|
| `Super + P` | 切换 passthrough 模式 |
| `Esc`（passthrough 中） | 返回 normal 模式 |

### 媒体与亮度（normal + locked）

| 按键 | 功能 |
|---|---|
| `XF86AudioRaiseVolume / LowerVolume` | 音量 ±1% |
| `XF86AudioMute` | 静音切换 |
| `XF86AudioMicMute` | 麦克风静音 |
| `XF86AudioPlay / Prev / Next` | 媒体控制 |
| `XF86MonBrightnessUp / Down` | 亮度 ±1% |

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
