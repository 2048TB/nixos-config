{
  river = {
    default = [ "gtk" ];
    "org.freedesktop.impl.portal.Inhibit" = [ "gtk" ];
    "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
    "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
    # gnome-keyring 的 .portal 文件声明 UseIn=gnome，在 river 桌面下不会被自动选中。
    # Chrome 等应用通过 portal Secret 接口获取加密密钥，缺少此路由会导致
    # os_crypt 初始化失败，每次启动弹出密码输入框。
    "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
  };
}
