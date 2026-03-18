{ pkgs
, lib
, mainUser
, configRepoPath
, ...
}:
let
  homeDir = "/home/${mainUser}";
  mainKeyPath = "/persistent/keys/main.agekey";
  expectedMainPub = builtins.replaceStrings [ "\n" "\r" ] [ "" "" ] (builtins.readFile ../../../secrets/keys/main.age.pub);
  bootstrapSourcePaths = [
    "${configRepoPath}/.keys/main.agekey"
    "/etc/nixos/.keys/main.agekey"
    "/home/${mainUser}/nixos/.keys/main.agekey"
  ];

  userPasswordSecretFile = ../../../secrets/passwords/user-password.yaml;
  rootPasswordSecretFile = ../../../secrets/passwords/root-password.yaml;
  githubSshPrivateSecretFile = ../../../secrets/ssh/github_id_ed25519.yaml;
  githubSshPublicSecretFile = ../../../secrets/ssh/github_id_ed25519_pub.yaml;
  aria2RpcSecretFile = ../../../secrets/services/aria2-rpc-secret.yaml;

  hasGithubSshPrivateSecret = builtins.pathExists githubSshPrivateSecretFile;
  hasGithubSshPublicSecret = builtins.pathExists githubSshPublicSecretFile;
  hasAria2RpcSecret = builtins.pathExists aria2RpcSecretFile;
in
{
  sops = {
    age.keyFile = mainKeyPath;

    secrets =
      {
        "passwords/user" = {
          sopsFile = userPasswordSecretFile;
          key = "value";
          neededForUsers = true;
          mode = "0400";
          owner = "root";
          group = "root";
        };
        "passwords/root" = {
          sopsFile = rootPasswordSecretFile;
          key = "value";
          neededForUsers = true;
          mode = "0400";
          owner = "root";
          group = "root";
        };
      }
      // lib.optionalAttrs hasGithubSshPrivateSecret {
        "ssh/github-private" = {
          sopsFile = githubSshPrivateSecretFile;
          key = "value";
          path = "${homeDir}/.ssh/id_ed25519";
          mode = "0400";
          owner = mainUser;
          group = mainUser;
        };
      }
      // lib.optionalAttrs hasGithubSshPublicSecret {
        "ssh/github-public" = {
          sopsFile = githubSshPublicSecretFile;
          key = "value";
          path = "${homeDir}/.ssh/id_ed25519.pub";
          mode = "0644";
          owner = mainUser;
          group = mainUser;
        };
      }
      // lib.optionalAttrs hasAria2RpcSecret {
        "services/aria2-rpc" = {
          sopsFile = aria2RpcSecretFile;
          key = "value";
          mode = "0400";
          owner = mainUser;
          group = mainUser;
        };
      };
  };

  system.activationScripts =
    {
      setupSecretsForUsers.deps = lib.mkAfter [ "sopsKeyBootstrap" ];

      sopsKeyBootstrap = {
        text = ''
          target_key="${mainKeyPath}"
          if [ ! -r "$target_key" ]; then
            age_keygen_bin="${pkgs.age}/bin/age-keygen"
            install_bin="${pkgs.coreutils}/bin/install"
            mkdir_bin="${pkgs.coreutils}/bin/mkdir"
            src=""

            for candidate in ${lib.concatMapStringsSep " " lib.escapeShellArg bootstrapSourcePaths}; do
              [ -r "$candidate" ] || continue
              candidate_pub="$("$age_keygen_bin" -y "$candidate" 2>/dev/null || true)"
              [ "$candidate_pub" = "${expectedMainPub}" ] || continue
              src="$candidate"
              break
            done

            if [ -z "$src" ]; then
              for candidate in /home/*/nixos/.keys/main.agekey; do
                [ -r "$candidate" ] || continue
                candidate_pub="$("$age_keygen_bin" -y "$candidate" 2>/dev/null || true)"
                [ "$candidate_pub" = "${expectedMainPub}" ] || continue
                src="$candidate"
                break
              done
            fi

            if [ -n "$src" ]; then
              "$mkdir_bin" -p /persistent/keys
              "$install_bin" -D -m 0400 -o root -g root "$src" "$target_key"
              echo "[sops] bootstrapped main identity key: $src -> $target_key"
            else
              echo "[sops] WARNING: main identity key missing at $target_key and no bootstrap source found." >&2
            fi
          fi
        '';
        deps = [ "specialfs" ];
      };

      ensureUserSshDir = {
        text = ''
          if id -u ${mainUser} >/dev/null 2>&1; then
            install -d -m 0700 -o ${mainUser} -g ${mainUser} ${homeDir}/.ssh
          fi
        '';
        deps = [ "users" ];
      };
    }
    // lib.optionalAttrs hasGithubSshPrivateSecret {
      repairGithubSshPrivateKey = {
        text = ''
          target="${homeDir}/.ssh/id_ed25519"
          cat_bin="${pkgs.coreutils}/bin/cat"
          head_bin="${pkgs.coreutils}/bin/head"
          install_bin="${pkgs.coreutils}/bin/install"
          mktemp_bin="${pkgs.coreutils}/bin/mktemp"
          od_bin="${pkgs.coreutils}/bin/od"
          rm_bin="${pkgs.coreutils}/bin/rm"
          stat_bin="${pkgs.coreutils}/bin/stat"
          tr_bin="${pkgs.coreutils}/bin/tr"

          if [ ! -f "$target" ]; then
            exit 0
          fi

          if [ "$("$head_bin" -n1 "$target" 2>/dev/null || true)" != "-----BEGIN OPENSSH PRIVATE KEY-----" ]; then
            exit 0
          fi

          size="$("$stat_bin" -c%s "$target" 2>/dev/null || echo 0)"
          if [ "$size" -le 0 ]; then
            exit 0
          fi

          last_byte="$("$od_bin" -An -tx1 -N1 -j "$(($size - 1))" "$target" | "$tr_bin" -d ' \n')"
          if [ "$last_byte" = "0a" ]; then
            exit 0
          fi

          tmp="$("$mktemp_bin" "${homeDir}/.ssh/id_ed25519.tmp.XXXXXX")"
          trap '$rm_bin -f "$tmp"' EXIT
          "$cat_bin" "$target" > "$tmp"
          printf '\n' >> "$tmp"
          "$install_bin" -m 0400 -o ${mainUser} -g ${mainUser} "$tmp" "$target"
          "$rm_bin" -f "$tmp"
          trap - EXIT
          echo "[sops] repaired missing trailing newline in $target"
        '';
        deps = [
          "setupSecretsForUsers"
          "ensureUserSshDir"
        ];
      };
    };
}
