{
  lib,
  host,
  vars,
  ...
}:
lib.mkIf (vars ? resumeOffset) {
  boot = {
    resumeDevice = "/dev/mapper/cryptroot-${host}";
    kernelParams = [
      "resume_offset=${toString vars.resumeOffset}"
    ];
  };
}
