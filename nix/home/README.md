# Home 配置目录结构

此目录包含用户 home-manager 配置的源文件和配置素材。

## 目录说明：

- `default.nix`
  - Home Manager 模块入口

- **configs/**          - 所有配置素材的统一目录
  - **niri/**           - Niri 窗口管理器配置（统一管理）
    - config.kdl        - 主配置（input, layout, animations, shadow）
    - keybindings.kdl   - 快捷键绑定
    - windowrules.kdl   - 窗口规则
    - noctalia-shell.kdl - Noctalia Shell 集成配置
    - niriswitcher.toml - 窗口切换器配置
    - niriswitcher-colors.css - 窗口切换器颜色
    - niriswitcher-style.css - 窗口切换器样式
  - **shell/**          - Shell 配置文件
    - zshrc             - Zsh 配置
    - bashrc            - Bash 配置
    - vimrc             - Vim 配置
  - **wallpapers/**     - 壁纸集合
  - **ghostty/**        - Ghostty 终端配置
  - **fcitx5/**         - Fcitx5 输入法配置（Pinyin + 中文维基词库）
  - **noctalia/**       - Noctalia Shell 配置

## 使用说明：

所有配置通过 `default.nix` 中的 symlink 方式链接到用户 home 目录。
修改这些文件后，运行 `just switch` 或 `home-manager switch` 应用更改。

## 软链接映射：

```
~/.config/niri/         → repo/nix/home/configs/niri/
~/.config/niriswitcher/ → repo/nix/home/configs/niri/niriswitcher*
~/.config/noctalia/     → repo/nix/home/configs/noctalia/
~/.config/ghostty/      → repo/nix/home/configs/ghostty/
~/.config/fcitx5/       → repo/nix/home/configs/fcitx5/
```
