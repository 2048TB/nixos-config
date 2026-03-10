# Repository Guidelines

## Project Structure & Module Organization
This repository is a cross-platform Nix flake. Active configuration lives under `nix/`, grouped as:

- `nix/shared/`: cross-platform shared helpers such as host validation and docs rendering.
- `nix/nixos/`, `nix/darwin/`, `nix/home/`: shared platform layers.
- `nix/hosts/<platform>/<host>/`: host-specific modules, including `vars.nix`, hardware, and host-only `home.nix` or `secrets.nix`.
- `nix/registry/`: host inventory used by `flake.nix`.
- `configs/`: user-facing app config sources (`niri/`, `ghostty/`, `yazi/`, etc.).
- `scripts/`: validation, rebuild, deploy, install, and operational helpers.
- `docs/`: generated and hand-written operational documentation.
- `legacy/`: old, non-imported configuration drafts. Do not edit unless explicitly requested.

## Build, Test, and Development Commands
- `./scripts/repo-check.sh`: primary repository validation. Runs shell syntax checks, `nixfmt --check`, hosts doc drift check, and `nix flake check`.
- `./scripts/repo-check.sh --full`: adds dry-run builds for all declared hosts.
- `nix build --dry-run .#nixosConfigurations.zly.config.system.build.toplevel`: verify a NixOS host evaluates to a system build.
- `nix build --dry-run '.#darwinConfigurations.mbp-work.system'`: verify the Darwin system output.
- `nix build --dry-run '.#homeConfigurations."z@mbp-work".activationPackage'`: verify standalone Home Manager output.

## Coding Style & Naming Conventions
Use two-space indentation in Nix files and keep formatting compatible with `nixfmt`. Prefer small, composable modules and minimal diffs. Name shared modules by purpose (`shared.nix`, `software.nix`), and keep host-specific extensions beside the host they affect, for example `nix/hosts/nixos/zly/secrets.nix`.

## Testing Guidelines
There is no unit-test framework in this repository. Validation is done through Nix evaluation, flake checks, and dry-run builds. After any structural or module change, run `./scripts/repo-check.sh`; after host-specific changes, also run the relevant dry-run build for that host.

## Commit & Pull Request Guidelines
Git history is not available in this workspace, so no local commit convention can be inferred. Use concise Conventional Commit style messages such as `fix: tighten darwin role validation` or `refactor: move host secrets into host directories`. PRs should include changed host/module paths, validation commands run, and any unverified scope.

## Security & Agent Workflow Notes
Never commit plaintext secrets or keys. `sops-age-key.txt` is ignored locally and must stay out of version control. AI agents should prefer conservative edits, preserve active architecture, update imports and docs when moving files, and avoid touching `legacy/` unless the task explicitly targets it.
