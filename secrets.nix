let
  main = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./secrets/keys/main.age.pub);
in
{
  "./secrets/passwords/user-password.age".publicKeys = [ main ];
  "./secrets/passwords/root-password.age".publicKeys = [ main ];
}
