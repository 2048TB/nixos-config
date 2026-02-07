{
  description = "NixOS desktop config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixpak = {
    #   url = "github:nixpak/nixpak";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };  # 已移除：nixpak 导致本地编译，直接使用官方包

    preservation.url = "github:nix-community/preservation";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = inputs@{ nixpkgs, nixpkgs-unstable, rust-overlay, home-manager, lanzaboote, niri, preservation, disko, ... }:
    let
      myvars = rec {
        # 用户配置
        username = "z";
        hostname = "zly";

        # 系统配置
        timezone = "Asia/Shanghai";

        # 存储配置
        # 默认目标盘（可通过环境变量 NIXOS_DISK_DEVICE 在安装时临时覆盖）
        diskDevice =
          let
            envDiskDevice = builtins.getEnv "NIXOS_DISK_DEVICE";
          in
          if envDiskDevice != "" then envDiskDevice else "/dev/nvme0n1";
        swapSizeGb = 32;

        # GPU 固定配置（不再依赖文件/环境变量）
        gpuMode = "amd-nvidia-hybrid";
        enableGpuSpecialisation = false;

        # 账户密码（SHA-512 哈希，使用 mkpasswd -m sha-512 生成）
        userPasswordHash = "$6$B3.x51Bo7NZ0zM7O$U39C/CBsG4gc.F.bn33fJRG6oJ4opRtHe9QIEucHA9bZWMZJup3Afr2oh082drER.6SIAw0eeVF6m5B51WDo40";
        rootPasswordHash = "$6$B3.x51Bo7NZ0zM7O$U39C/CBsG4gc.F.bn33fJRG6oJ4opRtHe9QIEucHA9bZWMZJup3Afr2oh082drER.6SIAw0eeVF6m5B51WDo40";

      };

      system = "x86_64-linux";

      mainUser = myvars.username;

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ rust-overlay.overlays.default ];
      };
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      specialArgs = inputs // {
        inherit myvars mainUser preservation;
      };
    in
    {
      # NixOS 配置
      nixosConfigurations.${myvars.hostname} = nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          ./nix/hosts/${myvars.hostname}.nix
          { nixpkgs.overlays = [ rust-overlay.overlays.default ]; }
          lanzaboote.nixosModules.lanzaboote
          niri.nixosModules.niri
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit myvars mainUser pkgsUnstable; };
              users.${mainUser} = import ./nix/home;
            };
          }
        ];
      };

      # 开发环境
      devShells.${system}.default = pkgs.mkShell {
        name = "nixos-config-dev";
        packages = with pkgs; [
          nix-tree # 依赖树查看
          nixpkgs-fmt
          statix
          deadnix
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
    };
}
