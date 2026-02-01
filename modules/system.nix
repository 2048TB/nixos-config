{ ... }:
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
  environment.systemPackages = [ ];
}
