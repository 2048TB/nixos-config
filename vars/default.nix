rec {
  # 用户配置
  username = "z";
  hostname = "nixos-cconfig";

  # 系统配置
  timezone = "Asia/Shanghai";

  # 路径配置
  configRoot = "/home/${username}/nixos-config";
  persistentRoot = "/persistent";

  # 网络配置
  networking = {
    gateway = "192.168.1.1";
    dns = [ "1.1.1.1" "8.8.8.8" ];
  };
}
