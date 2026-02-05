# Home 配置目录

该目录存放 Home Manager 配置与素材。

## 结构

- `default.nix` Home Manager 入口
- `configs/` 配置素材目录
- `configs/niri/` Niri KDL 配置
- `configs/noctalia/` Noctalia Shell 配置
- `configs/ghostty/` Ghostty 配置
- `configs/fcitx5/` Fcitx5 配置
- `configs/shell/` shell 配置（zsh/bash/vim）
- `configs/wallpapers/` 壁纸

## 使用方式

`default.nix` 通过 `mkOutOfStoreSymlink` 链接这些配置到用户目录。

应用更改：

```bash
just switch
```

## 重要说明

- Niri 使用手动 KDL 配置，`programs.niri.config = null`。
- 相关配置位置见：`nix/home/configs/niri/`。
