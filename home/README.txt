# Home 配置目录结构

此目录包含用户 home-manager 配置的源文件。

## 目录说明：

- **niri/**             - Niri 窗口管理器配置
  - config.kdl          - 主配置
  - keybindings.kdl     - 快捷键绑定
  - windowrules.kdl     - 窗口规则
  - niri-hardware.kdl   - 硬件相关配置
  - animation.kdl       - 动画配置
  - colors.kdl          - 颜色方案
  - scripts/            - 辅助脚本

- **shell/**            - Shell 配置文件
  - zshrc               - Zsh 配置
  - bashrc              - Bash 配置
  - vimrc               - Vim 配置

- **niriswitcher/**     - Niri 窗口切换器配置
  - config.toml         - 主配置
  - style.css           - 样式
  - colors.css          - 颜色

- **wallpapers/**       - 壁纸集合

- **ghostty/**          - Ghostty 终端配置

- **fcitx5/**           - Fcitx5 输入法配置

- **noctalia/**         - Noctalia Shell 配置

## 使用说明：

所有配置通过 `default.nix` 中的 symlink 方式链接到用户 home 目录。
修改这些文件后，运行 `home-manager switch` 应用更改。
