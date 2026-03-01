{ lib, myvars, binaryCaches, ... }:
let
  gcRetentionDays = myvars.gcRetentionDays or "7d";
  cacheSubstituters = binaryCaches.substituters;
  cacheTrustedPublicKeys = binaryCaches.trustedPublicKeys;
  acceptFlakeConfig = myvars.acceptFlakeConfig or false;
  extraTrustedUsers = myvars.extraTrustedUsers or [ ];
in
{
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];

      # 配置二进制缓存以加速包下载
      substituters = lib.mkForce (lib.unique ([ "https://cache.nixos.org" ] ++ cacheSubstituters));

      trusted-public-keys = lib.mkForce (lib.unique ([
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ] ++ cacheTrustedPublicKeys));

      # 默认仅 root 为 trusted user（官方文档：trusted user 近似 root 权限）。
      # 如需放宽，可在主机 vars.nix 增加 extraTrustedUsers = [ "alice" ];
      trusted-users = lib.mkForce (lib.unique ([ "root" ] ++ extraTrustedUsers));
      trusted-substituters = lib.mkForce (lib.unique cacheSubstituters);

      # 默认关闭，避免不受控地接受外部 flake 内嵌配置。
      accept-flake-config = acceptFlakeConfig;

      # 自动优化存储（硬链接重复文件）
      auto-optimise-store = true;
      builders-use-substitutes = true;
    };

    channel.enable = false;

    # 自动垃圾回收配置
    gc = {
      automatic = true;
      dates = "weekly"; # 每周执行一次
      options = "--delete-older-than ${gcRetentionDays}";
    };

    # 优化配置
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };
}
