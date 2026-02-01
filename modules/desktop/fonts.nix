{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    maple-mono.NF-CN-unhinted
    source-han-sans
    source-han-serif
    wqy_zenhei
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
  ];
}
