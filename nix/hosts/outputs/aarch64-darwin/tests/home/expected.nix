{ mainUsers }:
builtins.mapAttrs (_host: user: "/Users/${user}") mainUsers
