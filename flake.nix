{
  description = "NixOS desktop config (Niri + Home Manager)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
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
  };

  outputs = inputs: import ./outputs.nix inputs;
}
