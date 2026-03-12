{ lib, nixpkgs, ... }:
let
  nixCache = import ../../lib/nix-cache.nix;
  inherit (nixCache) cacheSubstituters cacheTrustedPublicKeys trustedUsers;
in
{
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];

      # 配置二进制缓存以加速包下载
      substituters = [ "https://cache.nixos.org/" ] ++ cacheSubstituters;

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ] ++ cacheTrustedPublicKeys;

      # mkForce：精确控制安全敏感设置，避免与 NixOS 默认 ["root"] 合并产生重复导致 eval check 失败
      trusted-users = lib.mkForce trustedUsers;
      # mkForce：安全可审计，精确控制可信 substituter 列表
      trusted-substituters = lib.mkForce (lib.unique cacheSubstituters);

      # 默认关闭，避免不受控地接受外部 flake 内嵌配置。
      accept-flake-config = false;

      # 自动优化存储（硬链接重复文件）
      auto-optimise-store = true;
      builders-use-substitutes = true;
    };

    # 固定 registry 到 flake.lock pin 的版本，避免 nix run nixpkgs#xxx 拉取最新
    registry.nixpkgs.flake = nixpkgs;
    nixPath = [ "nixpkgs=flake:nixpkgs" ];

    channel.enable = false;

    # 自动垃圾回收配置
    gc = {
      automatic = true;
      dates = "weekly"; # 每周执行一次
      options = "--delete-older-than 14d";
    };

  };
}
