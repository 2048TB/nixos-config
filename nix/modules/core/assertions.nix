{ lib, config, ... }:
let
  hostCfg = config.my.host;
  trustedUserAllowlist = [ hostCfg.username ];

  userPasswordSecretFile = ../../../secrets/passwords/user-password.yaml;
  rootPasswordSecretFile = ../../../secrets/passwords/root-password.yaml;
in
{
  assertions = [
    {
      assertion = builtins.pathExists userPasswordSecretFile;
      message = "Missing secrets/passwords/user-password.yaml. Use sops workflow to create/update it.";
    }
    {
      assertion = builtins.pathExists rootPasswordSecretFile;
      message = "Missing secrets/passwords/root-password.yaml. Use sops workflow to create/update it.";
    }
    {
      assertion =
        (!hostCfg.enableHibernate)
        || (hostCfg.resumeOffset != null && hostCfg.resumeOffset > 0);
      message = "When my.host.enableHibernate=true, set a positive integer my.host.resumeOffset (btrfs inspect-internal map-swapfile -r /swap/swapfile).";
    }
    {
      assertion = hostCfg.deployHost != "" && hostCfg.deployUser != "";
      message = "my.host.deployHost and my.host.deployUser must be non-empty strings.";
    }
    {
      assertion = lib.subtractLists trustedUserAllowlist hostCfg.extraTrustedUsers == [ ];
      message = "my.host.extraTrustedUsers contains disallowed users. allowed: only my.host.username.";
    }
  ];
}
