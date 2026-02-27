rec {
  description = "NixOS desktop config";

  # 仅影响 flake 自身（如 nix flake check / CI），不直接修改系统级 nix.conf。
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
      "https://cache.garnix.io"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

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

    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    preservation.url = "github:nix-community/preservation";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { nixpkgs, rust-overlay, home-manager, lanzaboote, nix-gaming, preservation, disko, pre-commit-hooks, ... }:
    let
      inherit (nixpkgs) lib;
      binaryCaches = {
        substituters = nixConfig."extra-substituters";
        trustedPublicKeys = nixConfig."extra-trusted-public-keys";
      };
      sharedPortalConfig = {
        common = {
          default = [ "gnome" "gtk" ];
          "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        };
        niri = {
          default = [ "gnome" "gtk" ];
          "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
          "org.freedesktop.impl.portal.Inhibit" = [ "gtk" ];
        };
      };

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
        # hibernate 恢复偏移（swapfile 场景）。
        # 用 root 执行：btrfs inspect-internal map-swapfile -r /swap/swapfile
        resumeOffset = 7709952;

        # GPU 固定配置（不再依赖文件/环境变量）
        gpuMode = "amd-nvidia-hybrid";
        enableGpuSpecialisation = false;

        # 账户密码（SHA-512 哈希，使用 mkpasswd -m sha-512 生成）
        userPasswordHash = "$6$pV3IR/1syWYqkNhu$wj.dgh8e7jm5eWRfTR/vKVyfqt3BjB1hHJv2tJlF1QlDxfGx89F2JzNm6pjZDsEzLlHwADQ28L9s.I5nqTn5u0";
        rootPasswordHash = "$6$E/rV.FZzRgxXAd4D$etON6WzH7IVVJDwcfOCCKwVsBtrGpsaNEBDMG8zj75mtziDDikfEZqgIo5kGvg70zozIby2zzGjJYjeG8Y0Bu1";

      };

      system = "x86_64-linux";
      mainUser = myvars.username;

      nixpkgsOverlays = [ rust-overlay.overlays.default ];
      nixpkgsConfig = {
        allowUnfree = true;
      };

      pkgs = import nixpkgs {
        inherit system;
        config = nixpkgsConfig;
        overlays = nixpkgsOverlays;
      };

      specialArgs = {
        inherit
          myvars
          mainUser
          binaryCaches
          sharedPortalConfig
          ;
      };

      homeManagerModule = {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "bak";
          extraSpecialArgs = specialArgs;
          users.${mainUser} = {
            imports = [
              ./nix/home
            ];
          };
        };
      };

      nixpkgsModule = {
        nixpkgs = {
          config = nixpkgsConfig;
          overlays = nixpkgsOverlays;
        };
      };

      hostModules = [
        nixpkgsModule
        preservation.nixosModules.default
        lanzaboote.nixosModules.lanzaboote
        nix-gaming.nixosModules.pipewireLowLatency
        nix-gaming.nixosModules.platformOptimizations
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        homeManagerModule
      ];

      nixosSystem = lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          ./nix/hosts/${myvars.hostname}.nix
        ] ++ hostModules;
      };

      preCommitCheck = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          nixpkgs-fmt.enable = true;
          statix.enable = true;
          deadnix.enable = true;
        };
      };
    in
    {
      nixosConfigurations.${myvars.hostname} = nixosSystem;

      # 轻量 eval checks
      checks.${system} =
        let
          cfg = nixosSystem.config;
          hmCfg = cfg.home-manager.users.${mainUser};
          expectedHome = "/home/${mainUser}";

          getNames = pkgList: lib.unique (map lib.getName pkgList);
          excludeAllowed = allowed: names: builtins.filter (n: !(builtins.elem n allowed)) names;

          allSystemPackageOutPaths = map (pkg: pkg.outPath) cfg.environment.systemPackages;
          systemPackageOutPaths = lib.unique allSystemPackageOutPaths;
          homePackageOutPaths = lib.unique (map (pkg: pkg.outPath) hmCfg.home.packages);
          systemHomeOverlapOutPaths = lib.intersectLists systemPackageOutPaths homePackageOutPaths;
          systemHomeOverlapPkgs = lib.filter (pkg: builtins.elem pkg.outPath systemHomeOverlapOutPaths) cfg.environment.systemPackages;
          systemHomeOverlapNames = getNames systemHomeOverlapPkgs;
          systemPackageNames = getNames cfg.environment.systemPackages;
          homePackageNames = getNames hmCfg.home.packages;
          unexpectedOverlapByName = lib.intersectLists systemPackageNames homePackageNames;
          systemDuplicateOutPaths =
            lib.unique (
              builtins.filter
                (outPath: (builtins.length (builtins.filter (p: p == outPath) allSystemPackageOutPaths)) > 1)
                allSystemPackageOutPaths
            );
          systemDuplicatePkgs =
            lib.filter
              (pkg: builtins.elem pkg.outPath systemDuplicateOutPaths)
              cfg.environment.systemPackages;
          systemDuplicateNames = getNames systemDuplicatePkgs;
          # 允许由上游模块隐式重复注入的基础包；其余重复视为回归。
          allowedSystemDuplicateNames = [
            "dosfstools"
            "fuse"
            "niri"
            "iptables"
            "less"
            "shadow"
            "zsh"
          ];
          unexpectedSystemDuplicateNames = excludeAllowed allowedSystemDuplicateNames systemDuplicateNames;
          # 仅允许基础运行时重叠（由模块隐式引入），其余视为回归。
          allowedSystemHomeOverlapNames = [
            "xwayland"
            "xdg-desktop-portal"
            "xdg-desktop-portal-gnome"
            "python3"
            "zsh"
            "nix-zsh-completions"
            "man-db"
            "shared-mime-info"
          ];
          unexpectedSystemHomeOverlapNames = excludeAllowed allowedSystemHomeOverlapNames systemHomeOverlapNames;
          unexpectedOverlapByNameFiltered = excludeAllowed allowedSystemHomeOverlapNames unexpectedOverlapByName;

          # 通用检查生成器：列表非空则报错
          mkNonEmptyCheck = name: items: msg:
            pkgs.runCommand name { } ''
              if [ ${toString (builtins.length items)} -ne 0 ]; then
                echo "${msg}: ${lib.concatStringsSep ", " items}" >&2
                exit 1
              fi
              touch "$out"
            '';
        in
        {
          eval-hostname = pkgs.runCommand "eval-hostname" { } ''
            test "${cfg.networking.hostName}" = "${myvars.hostname}"
            touch "$out"
          '';

          eval-home-directory = pkgs.runCommand "eval-home-directory" { } ''
            test "${hmCfg.home.homeDirectory}" = "${expectedHome}"
            touch "$out"
          '';

          eval-system-home-package-overlap = mkNonEmptyCheck
            "eval-system-home-package-overlap"
            unexpectedSystemHomeOverlapNames
            "Unexpected system/home package overlaps";

          eval-system-home-package-overlap-by-name = mkNonEmptyCheck
            "eval-system-home-package-overlap-by-name"
            unexpectedOverlapByNameFiltered
            "Unexpected system/home package overlaps by name";

          eval-system-package-duplicates = mkNonEmptyCheck
            "eval-system-package-duplicates"
            unexpectedSystemDuplicateNames
            "Unexpected duplicate packages in environment.systemPackages";

          pre-commit-check = preCommitCheck;
        };

      # 开发环境
      devShells.${system}.default = pkgs.mkShell {
        name = "nixos-config-dev";
        packages = with pkgs; [
          nix-tree # 依赖树查看
          nixpkgs-fmt
          statix
          deadnix
        ] ++ preCommitCheck.enabledPackages;
        shellHook = ''
          ${preCommitCheck.shellHook}
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
