{ hostNames, system }:
builtins.listToAttrs (
  map
    (name: {
      inherit name;
      value = system;
    })
    hostNames
)
