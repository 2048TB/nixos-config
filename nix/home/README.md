# Home 配置目录

该目录存放 Home Manager 配置与素材。

## 结构

- `default.nix` Home Manager 入口
- `configs/` 配置素材目录
- `configs/niri/` Niri KDL 配置
- `configs/waybar/` Waybar 配置
- `configs/wlogout/` Wlogout 配置
- `configs/qt6ct/` Qt6 主题配置
- `configs/ghostty/` Ghostty 配置
- `configs/fcitx5/` Fcitx5 配置
- `configs/shell/` shell 配置（zsh/bash/vim）
- `configs/wallpapers/` 壁纸

## 使用方式

`default.nix` 通过 Home Manager 的 `xdg.configFile` / `home.file` 管理这些配置文件。

应用更改：

```bash
just switch
```

## 重要说明

- Niri 使用手动 KDL 配置（`nix/home/configs/niri/*.kdl`）。
- 相关配置位置见：`nix/home/configs/niri/`。
