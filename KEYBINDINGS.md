# 快捷键说明

本文档基于当前配置文件：
- `nix/home/configs/niri/keybindings.kdl`
- `nix/home/configs/ghostty/config`
- `nix/home/configs/fuzzel/fuzzel.ini`
- `nix/home/configs/foot/foot.ini`

说明：Niri 中的 `Mod` 通常是 `Super`（Windows 键）。

---

## 窗口管理器（Niri）

基础操作：

| 快捷键 | 功能 |
|---|---|
| `Mod` + `Shift` + `/` | 显示快捷键帮助 |
| `Mod` + `O` | 打开/关闭概览（窗口与工作区缩略视图） |
| `Mod` + `Q` | 关闭当前窗口 |
| `Ctrl` + `Alt` + `Delete` | 退出会话（确认对话框） |
| `Mod` + `Escape` | 切换快捷键抑制模式 |

应用启动：

| 快捷键 | 功能 |
|---|---|
| `Mod` + `Enter` | 打开终端（Ghostty） |
| `Mod` + `Shift` + `Enter` | 打开浮动终端（Ghostty） |
| `Mod` + `Space` | 启动器（Fuzzel） |
| `XF86Search` | 启动器（Fuzzel） |
| `Mod` + `B` | 文件管理器（Nautilus） |
| `Mod` + `X` | 锁屏 |
| `Ctrl` + `Alt` + `L` | 锁屏 |

窗口焦点：

| 快捷键 | 功能 |
|---|---|
| `Mod` + `H/J/K/L` | 焦点移动（Vim 风格） |
| `Mod` + `←/↓/↑/→` | 焦点移动（方向键） |
| `Mod` + `N/M` | 焦点移到第一/最后一列 |

窗口/列移动：

| 快捷键 | 功能 |
|---|---|
| `Mod` + `Ctrl` + `H/J/K/L` | 移动列/窗口（Vim 风格） |
| `Mod` + `Ctrl` + `←/↓/↑/→` | 移动列/窗口（方向键） |
| `Mod` + `Shift` + `N/M` | 移动列到首/尾 |

多显示器：

| 快捷键 | 功能 |
|---|---|
| `Mod` + `Shift` + `H/J/K/L` | 焦点移到其他显示器 |
| `Mod` + `Shift` + `Ctrl` + `H/J/K/L` | 移动列到其他显示器 |

工作区：

| 快捷键 | 功能 |
|---|---|
| `Mod` + `U` / `Mod` + `Page Down` | 下一个工作区 |
| `Mod` + `I` / `Mod` + `Page Up` | 上一个工作区 |
| `Mod` + `Ctrl` + `U/I` | 移动列到上下工作区 |
| `Mod` + `Shift` + `U/I` | 移动整个工作区 |
| `Mod` + `Alt` + `U/I` | 发送当前窗口到上下工作区 |
| `Mod` + `1-9` | 切换到工作区（索引 1-9） |
| `Mod` + `Ctrl` + `1-9` | 移动当前列到工作区（索引 1-9） |
| `Mod` + `Alt` + `1-9` | 发送当前窗口到工作区（索引 1-9） |
| `Mod` + `Tab` | 切换到上一个工作区 |
| `Mod` + `Shift` + `W` | 新建并切换到空工作区 |

布局与尺寸：

| 快捷键 | 功能 |
|---|---|
| `Mod` + `R` | 切换列宽预设 |
| `Mod` + `Shift` + `R` | 切换窗口高度预设 |
| `Mod` + `Ctrl` + `R` | 重置窗口高度 |
| `Mod` + `F` | 最大化列 |
| `Mod` + `Shift` + `F` | 全屏窗口 |
| `Mod` + `Ctrl` + `F` | 扩展列到可用宽度 |
| `Mod` + `Shift` + `C` | 居中当前列 |
| `Mod` + `Ctrl` + `C` | 居中显示所有可见列 |
| `Mod` + `Y` | 切换窗口浮动/平铺 |
| `Mod` + `G` | 切换焦点：浮动窗口 ↔ 平铺窗口 |
| `Mod` + `W` | 切换列标签页模式 |
| `Mod` + `,` / `Mod` + `.` | 列宽 -10% / +10% |
| `Mod` + `/` / `Mod` + `;` | 窗口高度 -10% / +10% |

列内操作：

| 快捷键 | 功能 |
|---|---|
| `Mod` + `Ctrl` + `[` / `Mod` + `Ctrl` + `]` | 消费/驱逐窗口到左右列 |
| `Mod` + `Ctrl` + `,` | 消费右侧窗口到当前列底部 |
| `Mod` + `Ctrl` + `.` | 驱逐当前列底部窗口到右侧 |

截图：

| 快捷键 | 功能 |
|---|---|
| `Print` | 截图（niri 内置） |
| `Mod` + `A` | 区域截图 + 复制到剪贴板（保存到 `~/Pictures/Screenshots`） |
| `Ctrl` + `Print` | 全屏截图 |
| `Alt` + `Print` | 窗口截图 |

系统功能：

| 快捷键 | 功能 |
|---|---|
| `Mod` + `S` | 音量控制（pavucontrol） |
| `Mod` + `E` | 电源菜单（wlogout） |
| `Mod` + `Alt` + `V` | 剪贴板历史（cliphist + Fuzzel） |
| `Mod` + `Alt` + `C` | 计算器 |
| `Mod` + `Shift` + `P` | 关闭显示器 |

媒体与亮度：

| 快捷键 | 功能 |
|---|---|
| `XF86AudioRaiseVolume` | 增加音量 |
| `XF86AudioLowerVolume` | 降低音量 |
| `XF86AudioMute` | 静音/取消静音 |
| `XF86AudioMicMute` | 麦克风静音 |
| `XF86AudioPlay` | 播放/暂停 |
| `XF86AudioStop` | 停止播放 |
| `XF86AudioPrev` | 上一首 |
| `XF86AudioNext` | 下一首 |
| `XF86MonBrightnessUp` | 增加屏幕亮度 |
| `XF86MonBrightnessDown` | 降低屏幕亮度 |
| `XF86KbdBrightnessUp` | 增加键盘背光 |
| `XF86KbdBrightnessDown` | 降低键盘背光 |

---

## 终端（Ghostty）

复制粘贴：

| 快捷键 | 功能 |
|---|---|
| `Ctrl` + `Shift` + `C` | 复制 |
| `Ctrl` + `Shift` + `V` | 粘贴 |
| `Ctrl` + `V` | 已解绑（保留给 Vim visual block / Bash literal insert） |

清屏：

| 快捷键 | 功能 |
|---|---|
| `Ctrl` + `Shift` + `K` | 清屏 |
| `Ctrl` + `L` | 清屏（备选） |

标签页：

| 快捷键 | 功能 |
|---|---|
| `Ctrl` + `Shift` + `T` | 新建标签页 |
| `Ctrl` + `Shift` + `W` | 关闭标签页 |
| `Ctrl` + `Tab` | 下一个标签页 |
| `Ctrl` + `Shift` + `Tab` | 上一个标签页 |
| `Ctrl` + `1-9` | 切换到第 N 个标签页 |
| `Alt` + `1-9` | 切换到第 N 个标签页（备选） |

窗口：

| 快捷键 | 功能 |
|---|---|
| `Ctrl` + `Shift` + `N` | 新建窗口 |
| `F11` | 全屏切换 |

字体大小：

| 快捷键 | 功能 |
|---|---|
| `Ctrl` + `=` / `Ctrl` + `+` | 增大字体 |
| `Ctrl` + `-` | 减小字体 |
| `Ctrl` + `0` | 重置字体 |

滚动：

| 快捷键 | 功能 |
|---|---|
| `Shift` + `Page Up` | 向上翻页 |
| `Shift` + `Page Down` | 向下翻页 |
| `Shift` + `↑/↓` | 向上/下滚动一行 |

分割与面板：

| 快捷键 | 功能 |
|---|---|
| `Ctrl` + `A` 然后 `Shift` + `5` | 垂直分割（右侧新面板） |
| `Ctrl` + `A` 然后 `Shift` + `'` | 水平分割（下方新面板） |
| `Ctrl` + `A` 然后 `X` | 关闭当前面板 |
| `Ctrl` + `A` 然后 `Z` | 切换面板缩放 |
| `Ctrl` + `A` 然后 `H/J/K/L` | 面板导航（Vim 风格） |
| `Alt` + `H/J/K/L` | 面板导航（备选） |
| `Ctrl` + `←/→/↑/↓` | 调整面板大小 |

其他：

| 快捷键 | 功能 |
|---|---|
| `Ctrl` + `Shift` + `,` | 重新加载配置 |

---

## 终端（Foot）

复制粘贴：

| 快捷键 | 功能 |
|---|---|
| `Ctrl` + `Shift` + `C` | 复制 |
| `Ctrl` + `Shift` + `V` | 粘贴 |

字体大小：

| 快捷键 | 功能 |
|---|---|
| `Ctrl` + `+` / `Ctrl` + `=` | 增大字体 |
| `Ctrl` + `-` | 减小字体 |
| `Ctrl` + `0` | 重置字体 |

滚动：

| 快捷键 | 功能 |
|---|---|
| `Shift` + `Page Up` | 向上翻页 |
| `Shift` + `Page Down` | 向下翻页 |

其他：

| 快捷键 | 功能 |
|---|---|
| `Ctrl` + `Shift` + `N` | 新建窗口 |
| `Ctrl` + `Shift` + `R` | 搜索回滚缓冲区 |

---

## 配置文件位置

- Niri：`nix/home/configs/niri/keybindings.kdl`
- Fuzzel：`nix/home/configs/fuzzel/fuzzel.ini`
- Foot：`nix/home/configs/foot/foot.ini`
- Ghostty：`nix/home/configs/ghostty/config`

修改配置后执行：

```bash
sudo nixos-rebuild switch --flake /etc/nixos#zly
```

---

## Shell 快捷命令（zsh）

以下为命令行快捷函数（非 GUI 快捷键）：

| 命令 | 功能 |
|---|---|
| `ccv` | 启动 Claude Code（危险权限模式） |
| `ccv r` | 恢复 Claude Code 会话 |
| `cdx` | 启动 Codex（`--dangerously-bypass-approvals-and-sandbox`） |
| `cdx r` | 恢复 Codex 会话（`codex resume`） |
