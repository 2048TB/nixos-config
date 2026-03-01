# Repository Guidelines

## Project Structure & Module Organization
This repository is a flake-based NixOS desktop configuration.
- `flake.nix`: main entrypoint (`inputs`, `nixConfig`, `outputs`).
- `hosts/nixos/<host>/`: per-host NixOS definitions (`hardware.nix`, `disko.nix`, `vars.nix`; optional `home.nix`, `checks.nix`, `modules/`).
- `hosts/darwin/<host>/`: per-host Darwin definitions (`default.nix`, `vars.nix`; optional `home.nix`, `checks.nix`, `modules/`).
- `hosts/outputs/`: multi-platform flake output composition.
- `scripts/resolve-host.sh`: host resolution helper for local commands/apps (`ENV > hostname > fallback`).
- `scripts/new-host.sh`: host scaffolding helper for NixOS/Darwin host directories.
- `lib/default.nix`: shared helper + system assembly entry (`nixosSystem`, `macosSystem`, `mk*Host`).
- `apps/README.md`: flake app entrypoints (`nix run .#build-switch` etc.).
- `nix/modules/`: shared system modules (`system.nix`, `hardware.nix`).
- `nix/home/linux/default.nix`: Home Manager entrypoint for NixOS hosts.
- `nix/home/base|linux|darwin`: layered Home modules.
- `nix/home/configs/`: app configs — Ghostty, Foot, Tmux, Zellij, Waybar, Fuzzel, Wlogout, Yazi, shell, fcitx5, etc.
- Docs: `README.md`, `KEYBINDINGS.md`, `NIX-COMMANDS.md`, `CLAUDE.md`, `AGENTS.md`, `nix/home/README.md`.

## Build, Test, and Development Commands
Use `just` as the primary command runner:
- `just switch`: apply and activate the current config.
- `just switch-local`: resolve current host automatically and switch (preferred for daily use).
- `just test`: activate temporarily (reboot reverts).
- `just test-local`: resolve current host automatically and test.
- `just check`: dry-build validation without switching.
- `just check-local`: resolve current host automatically and check.
- `just darwin-check-local` / `just darwin-switch-local`: Darwin local host variants.
- `just new-nixos-host <name> [from]`: scaffold a new NixOS host from template.
- `just new-darwin-host <name> [from]`: scaffold a new Darwin host from template.
- `just eval-tests`: fast eval checks for hostname/home mapping.
- `just flake-check`: run `nix flake check` for flake-level validation.
- `just fmt`: format Nix files with `nixpkgs-fmt`.
- `just lint`: run `statix` checks.
- `just dead`: detect unused Nix code via `deadnix`.
- `just dev`: common dev flow (`fmt + flake-check + test`).
- Optional full build validation: `nix build --no-link path:/persistent/nixos-config#nixosConfigurations.zly.config.system.build.toplevel`.
- Optional app-style management (reference-aligned): `nix run .#build`, `nix run .#build-switch`.

## Coding Style & Naming Conventions
- Format Nix code with `nixpkgs-fmt` before review.
- Keep module boundaries clear: host-specific logic in `hosts/`, reusable logic in `nix/modules`.
- Follow existing naming patterns: lowercase kebab/camel mix already used in repo (e.g. `homeStateVersion`, `swapSizeGb`); keep new names consistent within the same file.
- Prefer minimal diffs and reuse existing module patterns instead of refactoring unrelated areas.

## Testing Guidelines
There is no unit-test suite; verification is configuration-driven:
- Run at least: `just eval-tests`, `just flake-check`, and target `just check` / `just check-local`.
- For Nix file edits, also run `just fmt` and `just lint`.
- For behavior validation, use `just test` before `just switch`.
- Include command outputs or a concise result summary in PR descriptions.

## Commit & Pull Request Guidelines
- Commit history follows Conventional Commit style (`fix:`, `feat:`, `refactor:`, `style:`) with optional scopes (e.g. `fix(foot): ...`).
- Write focused commits per concern (UI, module logic, docs).
- PRs should include: purpose, changed paths, verification commands run, rollback notes, and screenshots for visible UI changes.

## Documentation Sync Rules
- When behavior/commands/keybindings change, update related docs in the same change set.
- For Niri/Waybar/Tmux/Zellij changes, keep `README.md`, `KEYBINDINGS.md`, and `NIX-COMMANDS.md` consistent.
- If host discovery/scaffolding flow changes, sync `README.md`, `hosts/README.md`, `hosts/outputs/README.md`, and `apps/README.md`.
- If terminal multiplexer keybindings change, treat `nix/home/configs/tmux/tmux.conf` and `nix/home/configs/zellij/config.kdl` as source of truth and sync docs accordingly.
- If process rules change, sync `CLAUDE.md` and `AGENTS.md` together.
- If docs are updated and user requests Git sync, use a Conventional Commit message and push current branch.

## Security & Configuration Tips
- Do not commit new secrets (tokens, private keys, plaintext credentials). If rotating password hashes in `hosts/nixos/<host>/vars.nix`, treat them as sensitive changes and review carefully.
- Treat disk provisioning and install commands as destructive unless verified (disko-related flows).
