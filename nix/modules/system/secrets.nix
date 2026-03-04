{ pkgs
, lib
, myvars
, mainUser
, ...
}:
let
  homeDir = "/home/${mainUser}";
  configRepoPath = myvars.configRepoPath or "/persistent/nixos-config";
  agenixMainKeyPath = "/persistent/keys/main.agekey";
  expectedAgenixMainPub = builtins.replaceStrings [ "\n" "\r" ] [ "" "" ] (builtins.readFile ../../../secrets/keys/main.age.pub);
  agenixBootstrapSourcePaths = [
    "${configRepoPath}/.keys/main.agekey"
    "/etc/nixos/.keys/main.agekey"
    "/home/${mainUser}/nixos/.keys/main.agekey"
  ];
  ageIdentityPaths = [
    agenixMainKeyPath
    "/etc/ssh/ssh_host_ed25519_key"
    "/persistent/etc/ssh/ssh_host_ed25519_key"
  ];
  userPasswordSecretFile = ../../../secrets/passwords/user-password.age;
  rootPasswordSecretFile = ../../../secrets/passwords/root-password.age;
  githubSshPrivateSecretFile = ../../../secrets/ssh/github_id_ed25519.age;
  githubSshPublicSecretFile = ../../../secrets/ssh/github_id_ed25519.pub.age;
  hasGithubSshPrivateSecret = builtins.pathExists githubSshPrivateSecretFile;
  hasGithubSshPublicSecret = builtins.pathExists githubSshPublicSecretFile;
in
{
  age = {
    identityPaths = ageIdentityPaths;
    secrets =
      {
        "passwords/user" = {
          file = userPasswordSecretFile;
          mode = "0400";
          owner = "root";
          group = "root";
        };
        "passwords/root" = {
          file = rootPasswordSecretFile;
          mode = "0400";
          owner = "root";
          group = "root";
        };
      }
      // lib.optionalAttrs hasGithubSshPrivateSecret {
        "ssh/github-private" = {
          file = githubSshPrivateSecretFile;
          path = "${homeDir}/.ssh/id_ed25519";
          symlink = false;
          mode = "0400";
          owner = mainUser;
          group = mainUser;
        };
      }
      // lib.optionalAttrs hasGithubSshPublicSecret {
        "ssh/github-public" = {
          file = githubSshPublicSecretFile;
          path = "${homeDir}/.ssh/id_ed25519.pub";
          symlink = false;
          mode = "0644";
          owner = mainUser;
          group = mainUser;
        };
      };
  };

  system.activationScripts = {
    agenixNewGeneration.deps = lib.mkAfter [ "agenixKeyBootstrap" ];
    agenixInstall.deps = lib.mkAfter [ "agenixKeyBootstrap" ];

    agenixKeyBootstrap = {
      text = ''
        target_key="${agenixMainKeyPath}"
        if [ ! -r "$target_key" ]; then
          age_keygen_bin="${pkgs.age}/bin/age-keygen"
          install_bin="${pkgs.coreutils}/bin/install"
          mkdir_bin="${pkgs.coreutils}/bin/mkdir"
          src=""

          for candidate in ${lib.concatMapStringsSep " " lib.escapeShellArg agenixBootstrapSourcePaths}; do
            [ -r "$candidate" ] || continue
            candidate_pub="$("$age_keygen_bin" -y "$candidate" 2>/dev/null || true)"
            [ "$candidate_pub" = "${expectedAgenixMainPub}" ] || continue
            src="$candidate"
            break
          done

          if [ -z "$src" ]; then
            for candidate in /home/*/nixos/.keys/main.agekey; do
              [ -r "$candidate" ] || continue
              candidate_pub="$("$age_keygen_bin" -y "$candidate" 2>/dev/null || true)"
              [ "$candidate_pub" = "${expectedAgenixMainPub}" ] || continue
              src="$candidate"
              break
            done
          fi

          if [ -n "$src" ]; then
            "$mkdir_bin" -p /persistent/keys
            "$install_bin" -D -m 0400 -o root -g root "$src" "$target_key"
            echo "[agenix] bootstrapped main identity key: $src -> $target_key"
          else
            echo "[agenix] WARNING: main identity key missing at $target_key and no bootstrap source found." >&2
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
