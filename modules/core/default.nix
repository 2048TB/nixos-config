{ ... }:
{
  imports = [
    ./boot.nix
    ./nix.nix
    ./networking.nix
    ./security.nix
    ./users.nix
  ];

  # 时区
  time.timeZone = "Asia/Shanghai";

  # 系统级最小软件
  environment.systemPackages = [ ];
}
