{ pkgs
, lib
, myvars
, mainUser
, ...
}:
let
  homeDir = "/home/${mainUser}";
  inherit (myvars) configRepoPath;
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

  hasGithubSshPrivateSecret = builtins.pathExists githubSshPrivateSecretFile;
  hasGithubSshPublicSecret = builtins.pathExists githubSshPublicSecretFile;
in
{
  sops = {
    age.keyFile = mainKeyPath;

    secrets =
      {
        "passwords/user" = {
          sopsFile = userPasswordSecretFile;
          key = "value";
          mode = "0400";
          owner = "root";
          group = "root";
        };
        "passwords/root" = {
          sopsFile = rootPasswordSecretFile;
          key = "value";
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
      };
  };

  system.activationScripts = {
    setupSecrets.deps = lib.mkAfter [ "sopsKeyBootstrap" ];

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
  };
}
