{ self, nixpkgs, home-manager, lanzaboote, nixpak, preservation, ... }@inputs:
let
  myvars = import ../vars;
  mylib = import ../lib { inherit (nixpkgs) lib; };
  system = "x86_64-linux";

  # 向后兼容：支持环境变量覆盖
  envUser = builtins.getEnv "NIXOS_USER";
  mainUser = if envUser != "" then envUser else myvars.username;

  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  specialArgs = inputs // {
    inherit myvars mylib mainUser nixpak preservation;
  };
in
{
  # NixOS 配置
  nixosConfigurations.${myvars.hostname} = nixpkgs.lib.nixosSystem {
    inherit system specialArgs;
    modules = [
      ../hosts/${myvars.hostname}
      ../hardening/apparmor
      ../hardening/nixpaks
      lanzaboote.nixosModules.lanzaboote
      home-manager.nixosModules.home-manager
      {
        nixpkgs.config.allowUnfree = true;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = { inherit myvars mylib mainUser; };
        home-manager.users.${mainUser} = import ../home;
      }
    ];
  };

  # 开发环境
  devShells.${system}.default = pkgs.mkShell {
    name = "nixos-config-dev";
    packages = with pkgs; [
      nil                    # Nix LSP
      nixpkgs-fmt           # Nix 格式化
      statix                # Nix linter
      deadnix               # 死代码检测
      nix-tree              # 依赖树查看
    ];
    shellHook = ''
      echo "🚀 NixOS 配置开发环境"
      echo ""
      echo "可用命令："
      echo "  nixos-rebuild switch --flake .#${myvars.hostname}  - 应用配置"
      echo "  nixos-rebuild test --flake .#${myvars.hostname}    - 测试配置"
      echo "  nix flake check                                     - 检查 flake"
      echo "  nixpkgs-fmt .                                       - 格式化代码"
      echo "  statix check .                                      - 静态检查"
      echo "  deadnix .                                           - 查找死代码"
      echo ""
    '';
  };

  # 格式化器
  formatter.${system} = pkgs.nixpkgs-fmt;
}
