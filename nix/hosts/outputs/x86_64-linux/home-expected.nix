{ mainUsers }:
builtins.mapAttrs (_host: user: "/home/${user}") mainUsers
