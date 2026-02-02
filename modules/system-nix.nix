{ ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # 配置 Binary Cache 以加速包下载
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
    ];

    # 信任 wheel 组用户使用自定义 substituters
    trusted-users = [ "root" "@wheel" ];

    # 自动优化存储（硬链接重复文件）
    auto-optimise-store = true;
  };

  # 自动垃圾回收配置
  nix.gc = {
    automatic = true;
    dates = "weekly";        # 每周执行一次
    options = "--delete-older-than 7d";  # 删除 7 天前的旧世代
  };

  # 优化配置
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];    # 每周优化存储
  };
}
