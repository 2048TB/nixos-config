{ callPackage
, fetchzip
, fcft
, fetchgit
, kwmSrc
, lib
, libxkbcommon
, makeBinaryWrapper
, pixman
, pkg-config
, stdenv
, wayland
, wayland-protocols
, wayland-scanner
, zig_0_15
, kwim
,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "kwm-river";
  version = "unstable";

  src = kwmSrc;
  deps = callPackage ./build.zig.zon.nix { inherit fetchgit fetchzip; };

  nativeBuildInputs = [
    pkg-config
    wayland
    wayland-scanner
    zig_0_15.hook
    makeBinaryWrapper
  ];

  buildInputs = [
    fcft
    libxkbcommon
    pixman
    wayland-protocols
  ];

  zigBuildFlags = [
    "--system"
    "${finalAttrs.deps}"
  ];

  postFixup = ''
    wrapProgram "$out/bin/kwm" \
      --prefix PATH : "${lib.makeBinPath [ kwim ]}"
  '';

  meta = {
    description = "Window manager for the River Wayland compositor";
    homepage = "https://github.com/kewuaa/kwm";
    license = lib.licenses.gpl3Only;
    maintainers = [ ];
    mainProgram = "kwm";
    platforms = lib.platforms.linux;
  };
})
