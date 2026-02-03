{ lib, ... }:
{
  # 相对路径转绝对路径
  relativeToRoot = path: "${toString ../..}/${path}";

  # 扫描目录下所有 .nix 文件和子目录
  scanPaths = path:
    builtins.map
      (f: (path + "/${f}"))
      (builtins.attrNames
        (lib.filterAttrs
          (path: _type:
            (_type == "directory") ||
            (path != "default.nix" && lib.hasSuffix ".nix" path))
          (builtins.readDir path)));

  # 便捷的 home-manager 用户生成
  mkHomeUser = { username, modules }: {
    home-manager.users.${username} = { ... }: {
      imports = modules;
    };
  };

  # 智能导入目录下所有模块
  importModules = path:
    let
      entries = builtins.readDir path;
    in
    builtins.map
      (name: path + "/${name}")
      (builtins.filter
        (name:
          let
            type = entries.${name};
          in
          (type == "directory") ||
          (type == "regular" && name != "default.nix" && lib.hasSuffix ".nix" name))
        (builtins.attrNames entries));
}
