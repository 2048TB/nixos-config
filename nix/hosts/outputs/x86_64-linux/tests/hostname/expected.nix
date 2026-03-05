{ hostNames }:
builtins.listToAttrs (
  map
    (name: {
      inherit name;
      value = name;
    })
    hostNames
)
