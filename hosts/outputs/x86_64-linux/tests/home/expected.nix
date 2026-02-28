{ hostNames, mainUser }:
builtins.listToAttrs (
  map
    (name: {
      inherit name;
      value = "/home/${mainUser}";
    })
    hostNames
)
