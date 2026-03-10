{ inputs, lib, ... }:
let
  hardwareModules = map (name: builtins.getAttr name inputs.nixos-hardware.nixosModules) (
    import ./hardware-modules.nix
  );
in
{
  imports =
    hardwareModules
    ++ lib.optionals (builtins.pathExists ./hardware-workarounds.nix) [ ./hardware-workarounds.nix ]
    ++ lib.optionals (builtins.pathExists ./hardware-gpu-hybrid.nix) [ ./hardware-gpu-hybrid.nix ];
}
