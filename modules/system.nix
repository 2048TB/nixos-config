{ pkgs, ... }:
{
  imports = [
    ./system-boot.nix
    ./system-nix.nix
    ./system-networking.nix
    ./system-security.nix
    ./system-users.nix
  ];

  # 时区
  time.timeZone = "Asia/Shanghai";

  # 系统级最小软件
  environment.systemPackages = with pkgs; [
    vim
    neovim

    # 开发语言/工具链（系统级）
    rustc
    cargo
    rust-analyzer
    clippy
    rustfmt
    zig
    zls
    go
    gopls
    delve
    gotools
    nodejs
    nodePackages.typescript
    nodePackages.typescript-language-server
    python3
    pyright
    ruff
    black
    uv
  ];

  # 兼容通用 Linux 动态链接可执行文件（如第三方 CLI 安装器）
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      openssl
    ];
  };
}
