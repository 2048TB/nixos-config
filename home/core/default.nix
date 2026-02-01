{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # 基础 CLI 工具
    yazi
    bat
    fd
    eza
    ripgrep
    zellij
    btop
    fastfetch
    gnumake
    brightnessctl
    xdg-utils
    xdg-user-dirs
    git
    curl
    wget

    # Nix 生态工具
    nix-output-monitor  # nom - 构建日志美化
    nix-tree           # 依赖树可视化
    nix-melt           # flake.lock 查看器
    cachix             # 二进制缓存管理

    # 开发效率工具
    just               # 命令运行器
    sd                 # 查找替换（替代 sed）
    # xsv - 不在 nixpkgs 中，可用 csvkit 或 miller 替代
  ];
}
