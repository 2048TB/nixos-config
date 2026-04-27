{
  cli = [
    "bubblewrap"
    "ripgrep-all"
    "procs"
    "yq"
    "check-jsonschema"
    "tealdeer"
    "sshpass"
    "pciutils"
    "brightnessctl"
    "xdg-user-dirs"
  ];

  dev = [
    "gnumake"
    "cmake"
    "ninja"
    "pkg-config"
    "openssl"
    "autoconf"
    "gettext"
    "libtool"
    "automake"
    "ccache"
    "meson"
    "delta"
    "tokei"
    "nix-output-monitor"
    "nix-tree"
    "nix-melt"
    "cachix"
    "nil"
    "nixpkgs-fmt"
    "statix"
    "deadnix"
    "nix-index"
    "shellcheck"
    "git-lfs"
  ];

  desktop = [
    "google-chrome"
    "vscode"
    "remmina"
    "nomacs"
    "nautilus"
    "file-roller"
    "ghostty"
    "foot"
    "papirus-icon-theme"
    "wl-clipboard"
    "cliphist"
    "satty"
    "wl-screenrec"
    "gnome-text-editor"
    "fuzzel"
    "gnome-calculator"
    "qt6Packages.qt6ct"
    "app2unit"
    "polkit_gnome"
    "networkmanagerapplet"
  ];

  media = [
    "pavucontrol"
    "pulsemixer"
    "imv"
    "vulkan-tools"
    "mesa-demos"
  ];

  archive = [
    "p7zip-rar"
    "unar"
    "zip"
    "unzip"
  ];
}
