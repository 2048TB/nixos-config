{ lib, attrsLib }:
let
  inherit (attrsLib) hasNonEmptyString hasPositiveInt;
in
{
  assertPathExists = path: message: lib.assertMsg (builtins.pathExists path) message;

  assertNonEmptyAttrs = attrs: message: lib.assertMsg (attrs != { }) message;

  assertRequiredNonEmptyStrings =
    attrs: keys: where:
    builtins.all
      (
        key:
        lib.assertMsg
          (hasNonEmptyString attrs key)
          "Invalid ${where}: ${key} must be a non-empty string"
      )
      keys;

  assertRequiredPositiveInts =
    attrs: keys: where:
    builtins.all
      (
        key:
        lib.assertMsg
          (hasPositiveInt attrs key)
          "Invalid ${where}: ${key} must be a positive integer"
      )
      keys;
}
