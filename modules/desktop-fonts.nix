{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    # 编程字体
    maple-mono.NF-CN-unhinted # Nerd Font with Chinese glyphs

    # CJK 字体（已优化：移除 source-han 重复，仅保留 Noto）
    # 说明：source-han-sans 和 noto-fonts-cjk-sans 是同一套字体的不同品牌
    noto-fonts-cjk-sans # CJK 黑体（中日韩）
    noto-fonts-cjk-serif # CJK 宋体（中日韩）

    # 备用中文字体
    wqy_zenhei # 文泉驿正黑（轻量级，约 10MB）

    # 优化效果：移除 source-han-sans/serif 节省约 800MB
  ];
}
