{ lib, mylib, myvars, ... }:
let
  schema = mylib.hostMetaSchema;
  hostRoles = myvars.roles or schema.defaultRoles;
  enableHibernate = myvars.enableHibernate or true;
  dockerMode = myvars.dockerMode or schema.defaultDockerMode;
  extraTrustedUsers = myvars.extraTrustedUsers or [ ];
  trustedUserAllowlist = [ myvars.username ];

  mkOptionalBoolAssertion =
    optName:
    {
      assertion = !(builtins.hasAttr optName myvars) || builtins.isBool (builtins.getAttr optName myvars);
      message = "myvars.${optName} must be a boolean (true/false).";
    };
  mkOptionalStringAssertion =
    optName:
    {
      assertion = !(builtins.hasAttr optName myvars) || builtins.isString (builtins.getAttr optName myvars);
      message = "myvars.${optName} must be a string.";
    };
  mkOptionalNullableStringAssertion =
    optName:
    {
      assertion =
        !(builtins.hasAttr optName myvars)
        || (
          builtins.getAttr optName myvars == null
          || builtins.isString (builtins.getAttr optName myvars)
        );
      message = "myvars.${optName} must be null or a string.";
    };
  boolTypeAssertions = map mkOptionalBoolAssertion schema.optionalBoolOptions;
  stringTypeAssertions = map mkOptionalStringAssertion schema.optionalStringOptions;
  nullableStringTypeAssertions = map
    mkOptionalNullableStringAssertion
    schema.optionalNullableStringOptions;
  numericTypeAssertions = [
    {
      assertion =
        !(myvars ? swapSizeGb)
        || (builtins.isInt myvars.swapSizeGb && myvars.swapSizeGb > 0);
      message = "myvars.swapSizeGb must be a positive integer.";
    }
    {
      assertion =
        !(myvars ? resumeOffset)
        || (
          myvars.resumeOffset == null
          || (builtins.isInt myvars.resumeOffset && myvars.resumeOffset > 0)
        );
      message = "myvars.resumeOffset must be null or a positive integer.";
    }
  ];

  userPasswordSecretFile = ../../../secrets/passwords/user-password.age;
  rootPasswordSecretFile = ../../../secrets/passwords/root-password.age;
in
{
  assertions = [
    {
      assertion =
        !(myvars ? gpuMode)
          || (
          builtins.isString myvars.gpuMode
            && builtins.elem myvars.gpuMode schema.allowedGpuModes
        );
      message = "myvars.gpuMode must be one of: auto, none, amd, amdgpu, nvidia, nvidia-prime, modesetting, amd-nvidia-hybrid.";
    }
    {
      assertion =
        !(myvars ? cpuVendor)
          || (
          builtins.isString myvars.cpuVendor
            && builtins.elem myvars.cpuVendor schema.allowedCpuVendors
        );
      message = "myvars.cpuVendor must be one of: auto, amd, intel.";
    }
    {
      assertion =
        !(myvars ? dockerMode)
          || (
          builtins.isString myvars.dockerMode
            && builtins.elem dockerMode schema.allowedDockerModes
        );
      message = "myvars.dockerMode must be one of: rootless, rootful.";
    }
    {
      assertion = builtins.pathExists userPasswordSecretFile;
      message = "Missing secrets/passwords/user-password.age. Use agenix to create/update it.";
    }
    {
      assertion = builtins.pathExists rootPasswordSecretFile;
      message = "Missing secrets/passwords/root-password.age. Use agenix to create/update it.";
    }
    {
      assertion =
        (!enableHibernate)
          || (
          myvars ? resumeOffset
            && myvars.resumeOffset != null
            && builtins.isInt myvars.resumeOffset
            && myvars.resumeOffset > 0
        );
      message = "When myvars.enableHibernate=true, set a positive integer myvars.resumeOffset (btrfs inspect-internal map-swapfile -r /swap/swapfile).";
    }
    {
      assertion = builtins.isList hostRoles;
      message = "myvars.roles must be a list (e.g. [ \"desktop\" \"container\" ]).";
    }
    {
      assertion = builtins.all builtins.isString hostRoles;
      message = "myvars.roles must contain only strings.";
    }
    {
      assertion = lib.subtractLists schema.knownHostRoles hostRoles == [ ];
      message = "myvars.roles contains unknown values. allowed: desktop, gaming, vpn, virt, container.";
    }
    {
      assertion = builtins.isList extraTrustedUsers;
      message = "myvars.extraTrustedUsers must be a list (e.g. [ \"z\" ]).";
    }
    {
      assertion = builtins.all builtins.isString extraTrustedUsers;
      message = "myvars.extraTrustedUsers must contain only strings.";
    }
    {
      assertion = lib.subtractLists trustedUserAllowlist extraTrustedUsers == [ ];
      message = "myvars.extraTrustedUsers contains disallowed users. allowed: only myvars.username.";
    }
  ]
  ++ numericTypeAssertions
  ++ boolTypeAssertions
  ++ stringTypeAssertions
  ++ nullableStringTypeAssertions;
}
