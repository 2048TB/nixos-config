{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Rust 工具链
    rustc
    cargo
    rust-analyzer
    clippy
    rustfmt

    # Zig 工具链
    zig
    zls

    # Go 工具链
    go
    gopls
    delve
    gotools

    # Node.js / TypeScript
    nodejs
    nodePackages.typescript
    nodePackages.typescript-language-server

    # Python 工具链
    python3
    pyright
    ruff
    black
    uv
  ];
}
