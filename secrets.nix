let
  main = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./secrets/keys/main.age.pub);
in
{
  "./secrets/passwords/user-password.age".publicKeys = [ main ];
  "./secrets/passwords/root-password.age".publicKeys = [ main ];
  "./secrets/ssh/github_id_ed25519.age".publicKeys = [ main ];
  "./secrets/ssh/github_id_ed25519.pub.age".publicKeys = [ main ];
}
