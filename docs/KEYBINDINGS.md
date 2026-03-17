# 快捷键说明

当前 Linux 桌面已切换为 `river-classic + waybar`。

`Mod` = `Super`（Windows 键）。

---

## 1. 必会 12 个

| 快捷键 | 功能 |
|--------|------|
| `Mod + Return` | 打开终端 |
| `Mod + Space` | 启动器（Fuzzel） |
| `Mod + Q` | 关闭窗口 |
| `Mod + ↑/↓/←/→` | 切换窗口焦点 |
| `Mod + Tab` | 浮动/平铺切换 |
| `Mod + Z` | 全屏 |
| `Mod + W` | 按顺序切到下一张壁纸 |
| `Mod + 1..9` | 切到 tag |
| `Mod + Shift + 1..9` | 把窗口送到 tag |
| `Mod + ,/.` | 切换显示器焦点 |
| `Mod + A` | 区域截图并复制到剪贴板 |
| `XF86AudioRaiseVolume/LowerVolume` | 音量 |
| `Mod + Shift + X` | 锁屏 |

---

## 2. 应用与会话

| 快捷键 | 功能 |
|--------|------|
| `Mod + Return` | 终端 |
| `Mod + Space` | Fuzzel |
| `Mod + Shift + X` | 锁屏 |
| `Mod + W` | 按顺序切到下一张壁纸 |
| `Mod + Escape` | 会话菜单（Wlogout） |
| `Mod + Shift + E` | 退出 River |
| `Mod + P` | 进入 passthrough mode |
| `Mod + P`（在 passthrough mode 内） | 回到 normal mode |

---

## 3. 窗口与布局

| 快捷键 | 功能 |
|--------|------|
| `Mod + ↑/↓/←/→` | 切换左/右/上/下窗口焦点 |
| `Mod + Shift + G/L` | 左/右移动窗口 |
| `Mod + D/F` | 上/下移动窗口 |
| `Mod + Tab` | 浮动/平铺切换 |
| `Mod + Z` | 全屏 |
| `Mod + H/L` | 调整 `rivercarro` 主列比例 |
| `Mod + 鼠标左键拖动` | 移动窗口 |
| `Mod + 鼠标中键` | 浮动/平铺切换 |
| `Mod + 鼠标右键拖动` | 调整窗口大小 |

---

## 4. Tag 与多显示器

| 快捷键 | 功能 |
|--------|------|
| `Mod + 1..9` | 查看对应 tag |
| `Mod + Shift + 1..9` | 把当前窗口送到对应 tag |
| `Mod + Ctrl + 1..9` | 切换对应 tag 的显示状态 |
| `Mod + Ctrl + Shift + 1..9` | 切换当前窗口 tag 的附着状态 |
| `Mod + ,/.` | 聚焦上一个/下一个显示器 |
| `Mod + Shift + ,/.` | 把窗口送到上一个/下一个显示器 |

---

## 5. 截图与剪贴板

| 快捷键 | 功能 |
|--------|------|
| `Mod + A` | 区域截图，保存到 `~/Pictures/Screenshots/` 并复制到剪贴板 |
| `Mod + Shift + A` | 全屏截图，保存到 `~/Pictures/Screenshots/` 并复制到剪贴板 |
| `Print` | 区域截图，保存到 `~/Pictures/Screenshots/` 并复制到剪贴板 |
| `Ctrl + Print` | 全屏截图，保存到 `~/Pictures/Screenshots/` 并复制到剪贴板 |
| `Mod + V` | 剪贴板历史菜单 |

---

## 6. 音量与亮度

| 按键 | 功能 |
|------|------|
| `XF86AudioRaiseVolume/LowerVolume` | 音量增减（锁屏下也可用） |
| `XF86AudioMute` | 静音 |
| `XF86MonBrightnessUp/Down` | 屏幕亮度 |

---

## 7. Tmux（Prefix: `Ctrl + B`）

| 快捷键 | 功能 |
|--------|------|
| `Prefix + W/E` | 水平/垂直分屏 |
| `Prefix + Left/Down/Up/Right` | pane 焦点 |
| `Prefix + H/J/K/L` | 调整 pane 大小 |
| `Prefix + Q` | 关闭 pane |
| `Prefix + C` | 新建 window |
| `Prefix + D/S` | 下/上一个 window |
| `Prefix + Tab` | 切回上一个 window |
| `Prefix + G` | detach |
| `Prefix + R` | 重载配置 |

---

## 8. Zellij（Tmux Mode: `Ctrl + B`）

| 快捷键 | 功能 |
|--------|------|
| `Tmux + H/J/K/L` | pane 焦点 |
| `Tmux + A/D/E/F` | 调整 pane 大小 |
| `Tmux + S/V` | 分屏 |
| `Tmux + X` | 关闭 pane |
| `Tmux + C` | 新建 tab |
| `Tmux + W/Q` | 下/上一个 tab |
| `Tmux + R` | 切换布局 |
| `Tmux + G` | detach |

---

## 以配置文件为准

文档与实际不一致时，以源文件为准：
- `nix/home/configs/river/init`
- `nix/home/configs/tmux/tmux.conf`
- `nix/home/configs/zellij/config.kdl`
