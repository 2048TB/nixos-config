# 快捷键说明（新手版）

如果你刚开始用这套桌面，先记住“必会 12 个”，其余按需查表。

`Mod` = `Super`（Windows 键）。

---

## 1. 先记这 12 个

| 快捷键 | 功能 |
|---|---|
| `Mod + Return` | 打开终端 |
| `Mod + Space` | 打开应用启动器（Fuzzel） |
| `Mod + E` | 打开文件管理器 |
| `Mod + Q` | 关闭当前窗口 |
| `Mod + Left/Right` | 切换左右窗口焦点 |
| `Mod + 1..9` | 切到工作区 1..9 |
| `Mod + C` | 全屏当前窗口 |
| `Mod + X` | 浮动/平铺切换 |
| `Print` | 截图 |
| `XF86AudioRaiseVolume/LowerVolume` | 音量增减 |
| `Mod + Shift + L` | 锁屏 |
| `Mod + Shift + E` | 退出 Niri（有确认） |

---

## 2. 常用桌面快捷键

### 应用与会话

| 快捷键 | 功能 |
|---|---|
| `Mod + Shift + Return` | 浮动终端 |
| `Mod + Shift + Slash` | 显示快捷键提示层 |
| `Ctrl + Alt + Delete` | 退出 Niri（有确认） |

### 工作区与窗口

| 快捷键 | 功能 |
|---|---|
| `Mod + Page_Down / Page_Up` | 切换工作区 |
| `Mod + Ctrl + 1..9` | 把当前列移动到工作区 |
| `Mod + Alt + 1..9` | 把当前窗口移动到工作区 |
| `Mod + W` | 列 tabbed 显示切换 |
| `Mod + R` | 列宽预设循环 |
| `Mod + Shift + R` | 窗口高度预设循环 |
| `Mod + Z` | 当前列最大化 |

### 截图与剪贴板

| 快捷键 | 功能 |
|---|---|
| `Ctrl + Print` | 当前屏幕截图 |
| `Alt + Print` | 当前窗口截图 |
| `Mod + A` | 区域截图（保存并复制） |
| `Mod + Ctrl + C` | 剪贴板历史 |

### 媒体与亮度

| 按键 | 功能 |
|---|---|
| `XF86AudioMute` | 静音 |
| `XF86AudioMicMute` | 麦克风静音 |
| `XF86AudioPlay/Stop/Prev/Next` | 媒体控制 |
| `XF86MonBrightnessUp/Down` | 屏幕亮度 |

---

## 3. Tmux（Prefix: `Ctrl + B`）

| 快捷键 | 功能 |
|---|---|
| `Ctrl + B` | Prefix |
| `Prefix + W` / `E` | 水平/垂直分屏 |
| `Prefix + Left/Down/Up/Right` | pane 焦点切换 |
| `Prefix + Q` | 关闭 pane |
| `Prefix + C` | 新建 window |
| `Prefix + D` / `S` | 下一个/上一个 window |
| `Prefix + G` | detach |
| `Prefix + R` | 重载 tmux 配置 |

---

## 4. Zellij（Tmux Mode）

| 快捷键 | 功能 |
|---|---|
| `Ctrl + B`（Normal） | 进入 Tmux mode |
| `Tmux mode + H/J/K/L` | pane 焦点切换 |
| `Tmux mode + S` / `V` | 分屏 |
| `Tmux mode + X` | 关闭 pane |
| `Tmux mode + C` | 新建 tab |
| `Tmux mode + W` / `Q` | 下一个/上一个 tab |
| `Tmux mode + G` | detach |

---

## 5. 以配置文件为准

若文档与实际行为不一致，以以下文件为准：
- `nix/home/configs/niri/keybindings.kdl`
- `nix/home/configs/tmux/tmux.conf`
- `nix/home/configs/zellij/config.kdl`
