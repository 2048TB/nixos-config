{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # === 终端复用器 ===
    tmux               # 终端复用器（会话保持、多窗格）
    zellij             # 现代化终端复用器（Rust）

    # === 文件管理 ===
    yazi               # 终端文件管理器
    bat                # cat 增强版（语法高亮）
    fd                 # find 增强版（更快、更友好）
    eza                # ls 增强版（彩色、树状图）
    ripgrep            # grep 增强版（递归搜索）

    # === 系统监控 ===
    btop               # 系统资源监控（CPU、内存、进程）
    duf                # 磁盘使用查看（替代 df）
    fastfetch          # 系统信息展示

    # === 文本处理 ===
    jq                 # JSON 处理器（查询、格式化）
    sd                 # 查找替换（替代 sed）

    # === 网络工具 ===
    curl               # HTTP 请求工具
    wget               # 文件下载工具

    # === 基础工具 ===
    git                # 版本控制
    gnumake            # 构建工具
    brightnessctl      # 屏幕亮度控制
    xdg-utils          # XDG 工具集
    xdg-user-dirs      # 用户目录管理

    # === Nix 生态工具 ===
    nix-output-monitor # nom - 构建日志美化
    nix-tree           # 依赖树可视化
    nix-melt           # flake.lock 查看器
    cachix             # 二进制缓存管理

    # === 开发效率 ===
    just               # 命令运行器（替代 Makefile）
  ];
}
