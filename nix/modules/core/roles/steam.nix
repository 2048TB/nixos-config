{ lib, pkgs, config, mainUser, mylib, ... }:
let
  hostCfg = config.my.host;
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableSteam;
in
{
  programs = {
    # 游戏支持
    steam = lib.mkIf enableSteam {
      enable = true;
      gamescopeSession.enable = true;
      protontricks.enable = true;
      extest.enable = true; # Wayland 下将 X11 输入事件转换为 uinput（Steam Input 控制器支持）
      platformOptimizations.enable = true;
      # 局域网传输与 Remote Play 使用时自动放行防火墙端口
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;

      # Proton-GE 配置：通过 Steam 的 extraCompatPackages 安装
      # 注意：不能放在 environment.systemPackages（会导致 buildEnv 错误）
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };

    gamemode.enable = enableSteam;
  };

  # greetd 的 greeter 用户也会拉起一个 user manager；
  # 将仅主用户需要的 user services 绑定到 mainUser，避免 greeter 会话产生误报失败日志。
  systemd.user = lib.mkIf enableSteam {
    services.gamemoded.unitConfig.ConditionUser = mainUser;
  };
}
