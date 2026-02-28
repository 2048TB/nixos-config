{ hostNames, mainUser }:
builtins.listToAttrs (
  map
    (name: {
      inherit name;
      value = "/Users/${mainUser}";
    })
    hostNames
)
