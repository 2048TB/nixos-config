# Repository Guidelines

## Project Structure & Module Organization
This repository is a flake-based NixOS desktop configuration.
- `flake.nix`: main entrypoint (`inputs`, `nixConfig`, `outputs`).
- `hosts/vars/default.nix`: machine/user variables (host/user/GPU/password hash).
- `hosts/outputs/`: multi-platform flake output composition.
- `hosts/`: host-specific machine definitions (e.g. `nixos/zly/{hardware.nix,disko.nix}`, `darwin/zly-mac/default.nix`).
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
- `just test`: activate temporarily (reboot reverts).
- `just check`: dry-build validation without switching.
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
- Run at least: `just fmt`, `just lint`, `just flake-check`, and `just check`.
- For behavior validation, use `just test` before `just switch`.
- Include command outputs or a concise result summary in PR descriptions.

## Commit & Pull Request Guidelines
- Commit history follows Conventional Commit style (`fix:`, `feat:`, `refactor:`, `style:`) with optional scopes (e.g. `fix(foot): ...`).
- Write focused commits per concern (UI, module logic, docs).
- PRs should include: purpose, changed paths, verification commands run, rollback notes, and screenshots for visible UI changes.

## Documentation Sync Rules
- When behavior/commands/keybindings change, update related docs in the same change set.
- For Niri/Waybar/Tmux/Zellij changes, keep `README.md`, `KEYBINDINGS.md`, and `NIX-COMMANDS.md` consistent.
- If terminal multiplexer keybindings change, treat `nix/home/configs/tmux/tmux.conf` and `nix/home/configs/zellij/config.kdl` as source of truth and sync docs accordingly.
- If process rules change, sync `CLAUDE.md` and `AGENTS.md` together.
- If docs are updated and user requests sync, push current branch with a Conventional Commit message.

## Security & Configuration Tips
- Do not commit new secrets (tokens, private keys, plaintext credentials). If rotating password hashes in `hosts/vars/default.nix`, treat them as sensitive changes and review carefully.
- Treat disk provisioning and install commands as destructive unless verified (disko-related flows).
