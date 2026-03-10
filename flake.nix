{
  description = "Minimal cross-platform Nix configuration with NixOS, nix-darwin, home-manager, and sops-nix scaffolding";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      registry = builtins.fromTOML (builtins.readFile ./nix/registry/systems.toml);
      supportedSystems = [ "x86_64-linux" ];
      checkSystem = "x86_64-linux";
      requiredRuntimePrefixes = [
        "bun"
        "cargo"
        "go"
        "nodejs"
        "python3"
        "rustc"
        "uv"
        "zig"
      ];
      forEachSystem =
        f:
        lib.genAttrs supportedSystems (
          system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            }
          )
        );
      mkHostPath = platform: name: ./nix/hosts + "/${platform}/${name}";
      nixosHosts = builtins.attrNames (registry.nixos or { });
      darwinHosts = builtins.attrNames (registry.darwin or { });

      mkNixosSystem =
        host:
        let
          hostPath = mkHostPath "nixos" host;
          vars = import (hostPath + "/vars.nix");
          registryHost = registry.nixos.${host};
        in
        lib.nixosSystem {
          system = vars.system or "x86_64-linux";
          specialArgs = {
            inherit
              inputs
              host
              vars
              registryHost
              ;
            platform = "nixos";
            inherit (vars) username;
          };
          modules = [
            (hostPath + "/default.nix")
          ];
        };

      mkHomeConfiguration =
        {
          system,
          platform ? if lib.hasSuffix "darwin" system then "darwin" else "nixos",
          host,
          username,
          vars ? {
            inherit username;
            homeStateVersion = "25.11";
            timezone = "Asia/Shanghai";
          },
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          extraSpecialArgs = {
            inherit
              host
              platform
              username
              vars
              inputs
              ;
          };
          modules = [
            ./nix/home/base.nix
          ];
        };

      mkDarwinSystem =
        host:
        let
          hostPath = mkHostPath "darwin" host;
          vars = import (hostPath + "/vars.nix");
          registryHost = registry.darwin.${host};
        in
        nix-darwin.lib.darwinSystem {
          inherit (vars) system;
          specialArgs = {
            inherit
              inputs
              host
              vars
              registryHost
              ;
            platform = "darwin";
            inherit (vars) username;
          };
          modules = [
            (hostPath + "/default.nix")
          ];
        };
      mkRuntimeCheck =
        pkgs: label: packages:
        let
          packageNames = map lib.getName packages;
          missingRuntimePrefixes = builtins.filter (
            prefix: !(lib.any (name: lib.hasPrefix prefix name) packageNames)
          ) requiredRuntimePrefixes;
          checkName = builtins.replaceStrings [ "@" "." "/" "\"" "'" " " ] [ "-" "-" "-" "" "" "-" ] label;
        in
        pkgs.runCommand "${checkName}-runtime-check" { } ''
          if [ -n "${lib.concatStringsSep " " missingRuntimePrefixes}" ]; then
            echo "Missing required runtimes for ${label}: ${lib.concatStringsSep ", " missingRuntimePrefixes}" >&2
            exit 1
          fi

          touch "$out"
        '';
      mkNixosRuntimeChecks =
        pkgs:
        lib.listToAttrs (
          map (
            host:
            let
              hostVars = import (mkHostPath "nixos" host + "/vars.nix");
            in
            lib.nameValuePair "nixos-${host}-runtimes" (
              mkRuntimeCheck pkgs "nixos-${host}"
                nixosConfigurations.${host}.config.home-manager.users.${hostVars.username}.home.packages
            )
          ) nixosHosts
        );
      mkDarwinRuntimeChecks =
        pkgs:
        lib.listToAttrs (
          map (
            host:
            let
              hostVars = import (mkHostPath "darwin" host + "/vars.nix");
            in
            lib.nameValuePair "darwin-${host}-runtimes" (
              mkRuntimeCheck pkgs "darwin-${host}"
                darwinConfigurations.${host}.config.home-manager.users.${hostVars.username}.home.packages
            )
          ) darwinHosts
        );
      nixosConfigurations = lib.genAttrs nixosHosts mkNixosSystem;
      darwinConfigurations = lib.genAttrs darwinHosts mkDarwinSystem;
      homeConfigurations = {
        "z@template-linux" = mkHomeConfiguration {
          system = "x86_64-linux";
          platform = "nixos";
          host = "template-linux";
          username = "z";
        };
        "z@mbp-work" = mkHomeConfiguration {
          system = "aarch64-darwin";
          platform = "darwin";
          host = "mbp-work";
          username = "z";
          vars = import ./nix/hosts/darwin/mbp-work/vars.nix;
        };
      };
    in
    {
      inherit nixosConfigurations darwinConfigurations homeConfigurations;

      formatter = forEachSystem (pkgs: pkgs.nixfmt);

      apps = forEachSystem (
        pkgs:
        lib.optionalAttrs pkgs.stdenv.isLinux {
          nixos-anywhere = {
            type = "app";
            program = "${
              inputs.nixos-anywhere.packages.${pkgs.stdenv.hostPlatform.system}.default
            }/bin/nixos-anywhere";
            meta.description = "Pinned nixos-anywhere installer from this flake lock";
          };
        }
      );

      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            age
            deadnix
            git
            nh
            nix-output-monitor
            nixfmt
            nvd
            sops
            ssh-to-age
            statix
          ];
        };
      });

      checks = lib.genAttrs [ checkSystem ] (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          deadnix = pkgs.runCommand "deadnix-check" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
            cd ${self}
            deadnix --fail .
            touch "$out"
          '';
          statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
            cd ${self}
            statix check .
            touch "$out"
          '';
          standalone-template-linux-runtimes =
            mkRuntimeCheck pkgs "standalone-template-linux"
              homeConfigurations."z@template-linux".config.home.packages;
          standalone-mbp-work-runtimes =
            mkRuntimeCheck pkgs "standalone-mbp-work"
              homeConfigurations."z@mbp-work".config.home.packages;
        }
        // mkNixosRuntimeChecks pkgs
        // mkDarwinRuntimeChecks pkgs
      );
    };
}
