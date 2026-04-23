{ callPackage
, fetchzip
, fetchgit
, kwimSrc
, lib
, libxkbcommon
, pkg-config
, stdenv
, wayland
, wayland-protocols
, wayland-scanner
, zig_0_15
,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "kwim";
  version = "unstable";

  src = kwimSrc;
  deps = callPackage ./build.zig.zon.nix { inherit fetchgit fetchzip; };

  nativeBuildInputs = [
    pkg-config
    wayland
    wayland-scanner
    zig_0_15.hook
  ];

  buildInputs = [
    libxkbcommon
    wayland-protocols
  ];

  zigBuildFlags = [
    "--system"
    "${finalAttrs.deps}"
  ];

  meta = {
    description = "Input manager for the River Wayland compositor";
    homepage = "https://github.com/kewuaa/kwim";
    license = lib.licenses.gpl3Only;
    maintainers = [ ];
    mainProgram = "kwim";
    platforms = lib.platforms.linux;
  };
})
