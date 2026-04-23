# 快捷键说明

本页是快捷键摘要，不是事实源。行为与映射若有冲突，以配置文件为准。

先记住“必会 15 个”，其余按需查表。

`Mod` = `Super`（Windows 键）；winit 窗口环境中 = `Alt`。

---

## 1. 必会 15 个

| 快捷键 | 功能 |
|--------|------|
| `Mod + Return` | 打开 `ghostty` |
| `Mod + Shift + Return` | 打开 `foot` |
| `Mod + Space` | 启动器（Fuzzel） |
| `Mod + Q` | 关闭窗口 |
| `Mod + Left/Down/Up/Right` | 切到上一个 / 下一个窗口（Niri 兼容别名） |
| `Mod + J/K` | 切到下一个 / 上一个窗口 |
| `Mod + S/G` | 与上一个 / 下一个窗口交换位置（Niri 兼容别名） |
| `Mod + 1..9` | 切到 tag |
| `Mod + Shift + 1..9` / `Mod + Alt + 1..9` | 把当前窗口送到 tag |
| `Mod + P` | 切回上一个 tag |
| `Mod + M` | 全屏 |
| `Mod + W` | 切换浮动 |
| `Mod + T` / `Mod + Alt + G/D/S/F` | 切换 `tile` / `grid` / `deck` / `scroller` / `float` |
| `Mod + B` | 切换 kwm bar |
| `Print` | 全屏保存截图 |
| `Shift + Print` | 区域保存截图 |
| `Mod + Shift + A` | 区域保存截图（Niri 兼容别名） |
| `Ctrl + Print` | 全屏复制截图 |
| `Ctrl + Shift + Print` | 区域复制截图 |
| `XF86AudioRaiseVolume/LowerVolume` | 音量 |
| `Mod + Shift + L` | 锁屏（swaylock-effects） |
| `Mod + Shift + P` | 关闭显示器 |
| `Mod + Shift + W` | 切到下一张壁纸 |
| `Mod + Shift + E` | 退出 `river` 会话 |

---

## 2. 应用与会话

| 快捷键 | 功能 |
|--------|------|
| `Mod + Return` | `ghostty` |
| `Mod + Shift + Return` | `foot` |
| `Mod + Space` | `fuzzel` |
| `XF86Search` | `fuzzel` |
| `Mod + Shift + L` | 运行 `~/.config/river/lock.sh` |
| `Mod + Shift + P` | 运行 `~/.config/river/dpms-off.sh` |
| `Mod + Shift + W` | 运行 `~/.config/river/wallpaper.sh next` |
| `Mod + Shift + R` | 重载 `kwm` 配置 |
| `Mod + Shift + E` | 退出 `river` 会话 |
| `Ctrl + Alt + Delete` | 退出 `river` 会话 |

---

## 3. 窗口导航与移动

鼠标移到窗口上会自动聚焦该窗口。

| 快捷键 | 功能 |
|--------|------|
| `Mod + Left/Down/Up/Right` | 聚焦上一个 / 下一个窗口（Niri 兼容别名） |
| `Mod + J/K` | 聚焦下一个 / 上一个窗口 |
| `Mod + Shift + J/K` | 与下一个 / 上一个窗口交换位置 |
| `Mod + S/G` | 与上一个 / 下一个窗口交换位置（Niri 兼容别名） |
| `Mod + , / .` | 聚焦上一个 / 下一个显示器 |
| `Mod + Shift + , / .` | 发送窗口到上一个 / 下一个显示器 |
| `Mod + Shift + Alt + H/J/K/L` | 聚焦上一个 / 下一个显示器（Niri 兼容别名，线性输出） |
| `Mod + Ctrl + H/J/K/L` | 发送窗口到上一个 / 下一个显示器（Niri 兼容别名，线性输出） |
| `Mod + W` | 切换当前窗口浮动 |
| `Mod + E` | 在当前窗口与主窗口间切换焦点 |
| `Mod + M` | 切换全屏 |
| `Mod + Shift + M` | 切换最大化 |
| `Mod + Ctrl + Shift + F` | 切换窗口内全屏 |
| `Mod + Q` | 关闭窗口 |

---

## 4. 多显示器

| 快捷键 | 功能 |
|--------|------|
| `Mod + , / .` | 聚焦上一个 / 下一个显示器 |
| `Mod + Shift + , / .` | 把当前窗口发送到上一个 / 下一个显示器 |
| `Mod + Shift + Alt + H/J/K/L` | 聚焦上一个 / 下一个显示器（Niri 兼容别名，线性输出） |
| `Mod + Ctrl + H/J/K/L` | 发送窗口到上一个 / 下一个显示器（Niri 兼容别名，线性输出） |

---

## 5. 工作区

| 快捷键 | 功能 |
|--------|------|
| `Mod + 1..9` | 激活单个 tag |
| `Mod + 0` | 激活全部 tag |
| `Mod + Page_Down/Page_Up` | 激活下一个 / 上一个 tag |
| `Mod + Alt + Right/Left` | 激活下一个 / 上一个 tag（Niri 兼容别名） |
| `Mod + N` / `Mod + Alt + Down` | 激活下一个空 tag |
| `Mod + Ctrl + 1..9` | 切换某个 tag 的显示状态 |
| `Mod + Shift + 1..9` | 把当前窗口指派到 tag |
| `Mod + Alt + 1..9` | 把当前窗口指派到 tag（Niri 兼容别名） |
| `Mod + Shift + 0` | 把当前窗口指派到全部 tag |
| `Mod + Ctrl + Page_Down/Page_Up` | 把当前窗口指派到下一个 / 上一个 tag |
| `Mod + D/F` | 把当前窗口指派到下一个 / 上一个 tag（Niri 兼容别名） |
| `Mod + Tab` | 切回上一个 tag |
| `Mod + P` | 切回上一个 tag（Niri 兼容别名） |

---

## 6. 布局与尺寸

默认布局为 `scroller`，用于接近旧 `Niri` 的滚动窗口工作流。

| 快捷键 | 功能 |
|--------|------|
| `Mod + T` | `tile` 布局 |
| `Mod + Alt + G` | `grid` 布局 |
| `Mod + Alt + D` | `deck` 布局 |
| `Mod + Alt + S` | `scroller` 布局 |
| `Mod + Ctrl + M` | `monocle` 布局 |
| `Mod + Alt + F` | `float` 布局 |
| `Mod + H/L` | 缩小 / 扩大主区域 |
| `Mod + - / =` | 减少 / 增加主区域窗口数 |
| `Mod + Alt + - / =` | 减少 / 增加 gap |
| `Mod + Z` | 把当前窗口提升到主区域 / 居中 scroller 窗口 |

---

## 7. 截图与剪贴板

| 快捷键 | 功能 |
|--------|------|
| `Print` | 全屏保存（`grim`） |
| `Shift + Print` | 区域保存（`grim + slurp`） |
| `Mod + Shift + A` | 区域保存（Niri 兼容别名） |
| `Ctrl + Print` | 全屏复制到剪贴板 |
| `Ctrl + Shift + Print` | 区域复制到剪贴板 |

---

## 8. 媒体与亮度

| 按键 | 功能 |
|------|------|
| `XF86AudioRaiseVolume/LowerVolume` | 音量（锁屏可用） |
| `XF86AudioMute` | 静音 |
| `XF86AudioMicMute` | 麦克风静音 |
| `XF86AudioPlay/Stop/Prev/Next` | 媒体控制 |
| `XF86MonBrightnessUp/Down` | 屏幕亮度 |
| `XF86KbdBrightnessUp/Down` | 键盘背光 |

---

## 9. Tmux（Prefix: `Ctrl + B`）

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

## 10. Zellij（Tmux Mode: `Ctrl + B`）

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

## 11. Yazi

这套 `Yazi` 键位以官方 `26.1.22` 语义为基线，但主层按 `Sofle` 左手区重排成“导航 + 编辑 + 跳转”工作区：高频编辑动作集中到 `s d f r z x c v .` 一带，`a*` 单独作为创建前缀组，方向键继续负责移动与目录进退。根据当前 opener 配置，文本类文件默认优先走 `nvim`，也可在交互式 opener 中切到 `gnome-text-editor`；常见开发配置文件（如 `.nix`、`.env*`、`.service`、`.desktop`）会直接命中编辑规则；图片用 `imv`，视频/音频用 `mpv`，PDF 用 `zathura`，目录可交给 `nautilus`，常见 tarball/压缩包会优先交给归档 opener，其余回退到 `xdg-open`。

当前分组规则：
- 主层单键：`q w e r / s d f z x c v .`
- `a*` = 创建（`aa` 目录，`as` 文件/通用创建）
- `b*` = 快速跳转（交互式 `cd` / `zoxide` / `fzf`）
- `h*` = 内容搜索与查找跳转
- `z*` = 跳转（`zoxide` / `fzf`）
- `p*` = 低频文件操作（强制粘贴 / 取消 yank / 软链接 / 永久删除）
- `u*` = 撤销 / 取消（取消 yank / filter / search）
- `y*` = 路径复制
- `l*` = linemode
- `g*` = 目录跳转与快速 goto
- `t*` = tab 与任务
- `,*` = 排序

| 快捷键 | 功能 |
|--------|------|
| `q` | 退出，并按 `--cwd-file` 约定写回当前目录 |
| `Ctrl + Q` | 退出，但不写回 `cwd-file` |
| `Ctrl + C` | 关闭当前 tab；若已是最后一个 tab，则直接退出 |
| `Ctrl + Z` | suspend `Yazi` 回到 shell；可用 `fg` 返回 |
| `Left` / `Right` | 返回上级目录 / 进入目录 |
| `Up` / `Down` | 上移 / 下移（支持首尾回绕） |
| `e` / `w` | 后退到上一个目录 / 前进到下一个目录 |
| `gg` / `gb` | 跳到顶部 / 跳到底部 |
| `Ctrl + U` / `Ctrl + D` | 上翻半页 / 下翻半页 |
| `Ctrl + B` / `Ctrl + F` | 上翻一页 / 下翻一页 |
| `Enter` / `oo` | 按 opener 规则打开 / 交互式选择 opener |
| `f` / `h` | 按文件名搜索（`fd`）/ 按内容搜索（`rg`） |
| `/` | 过滤当前列表 |
| `hv` | 切到 flat view（通过 `fd -d 3` 展平到 3 层） |
| `hn` / `hp` | 向前查找 / 向后查找 |
| `hd` / `hq` | 下一个 / 上一个匹配项 |
| `Ctrl + S` | 仅取消当前 search |
| `z` / `zz` | `zoxide` 跳历史目录 / `fzf` 在当前树中 fuzzy jump |
| `bb` / `bz` / `bf` | 交互式 `cd` / `zoxide` 跳历史目录 / `fzf` 在当前树中 fuzzy jump |
| `Space` | 切换当前项选择状态，并下移一行 |
| `Ctrl + A` / `Ctrl + R` | 全选 / 反转选择 |
| `s` / `sx` | 进入选择模式 / 进入反选模式 |
| `aa` / `as` | 创建目录 / 创建文件（也可输入 `/` 结尾创建目录） |
| `r` / `d` | 重命名（光标停在扩展名前）/ 移到回收站 |
| `x` / `c` / `v` | 剪切 / 复制 / 粘贴 |
| `pf` / `pq` | 强制覆盖粘贴 / 取消当前 yank 状态 |
| `uu` / `uf` / `us` | 取消 yank / 取消 filter / 取消 search |
| `p-` / `p+` / `pz` | 建立绝对路径软链接 / 相对路径软链接 / 永久删除 |
| `yy` / `yd` / `yf` / `ye` | 复制绝对路径 / 目录路径 / 文件名 / 无扩展名文件名 |
| `ii` / `.` | 查看当前项信息 / 显示或隐藏隐藏文件 |
| `,n` / `,s` / `,m` | 按自然序 / 大小 / 修改时间排序 |
| `,a` / `,d` / `,t` | 按自然序 / 大小 / 修改时间倒序排序 |
| `ls/lp/lb/lm/lo/ln` | 切换 linemode：size / permissions / btime / mtime / owner / none |
| `ga` / `gb` / `gd` / `gc` / `gs` / `gr` / `gt` | 跳到 `~` / 列表底部 / `~/Downloads` / `~/.config` / `/persistent` / `/persistent/nixos-config` / `/tmp` |
| `g Space` / `gf` | 交互式跳转 / 跟随当前符号链接 |
| `;` / `'` | 异步 shell / 同步阻塞 shell |
| `tt` / `tb` | 在当前目录新建 tab / 在 Home 新建 tab |
| `tq/tw/te/tr/tf` | 直接跳到第 1 到第 5 个 tab |
| `ta` / `td` | 上一个 tab / 下一个 tab |
| `tz` / `tc` | 当前 tab 与前一个 / 后一个 tab 交换位置 |
| `ts` / `tx` | 打开任务列表 / 关闭当前 tab |
| `Esc` / `Ctrl + [` | 自动取消当前状态：退出 visual、清空选择、取消 `find` / `filter` / `search` |
| `F1` | 打开帮助 |

---

## 事实源

文档与实际不一致时，以这些源文件为准：
- `nix/home/configs/kwm/config.zon`
- `nix/home/configs/river/lock.sh`
- `nix/home/configs/river/screenshot.sh`
- `nix/home/configs/tmux/tmux.conf`
- `nix/home/configs/zellij/config.kdl`
- `nix/home/configs/yazi/keymap.toml`
- `nix/home/configs/yazi/yazi.toml`
