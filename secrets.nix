let
  strip = s: builtins.replaceStrings [ "\n" "\r" ] [ "" "" ] s;
  readKey = path: strip (builtins.readFile path);

  main = readKey ./secrets/keys/main.age.pub;
  recoveryPath = ./secrets/keys/recovery.age.pub;
  hostKeysDir = ./secrets/keys/hosts;
  hostDirEntries = if builtins.pathExists hostKeysDir then builtins.readDir hostKeysDir else { };
  hostKeyFiles = builtins.filter
    (name: hostDirEntries.${name} == "regular" && builtins.match ".*\\.pub" name != null)
    (builtins.attrNames hostDirEntries);
  hostRecipients = builtins.map (name: readKey (hostKeysDir + "/${name}")) hostKeyFiles;

  recipientsRaw =
    [ main ]
    ++ (if builtins.pathExists recoveryPath then [ (readKey recoveryPath) ] else [ ])
    ++ hostRecipients;
  recipients = builtins.foldl'
    (acc: key:
      if key == "" || builtins.elem key acc then acc else acc ++ [ key ]
    ) [ ]
    recipientsRaw;
in
{
  "./secrets/passwords/user-password.age".publicKeys = recipients;
  "./secrets/passwords/root-password.age".publicKeys = recipients;
  "./secrets/ssh/github_id_ed25519.age".publicKeys = recipients;
  "./secrets/ssh/github_id_ed25519.pub.age".publicKeys = recipients;
}
