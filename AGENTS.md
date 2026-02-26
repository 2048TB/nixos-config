# Repository Guidelines

## Project Structure & Module Organization
This repository is a flake-based NixOS desktop configuration.
- `flake.nix`: main entrypoint (`inputs`, `outputs`, host wiring, `myvars`).
- `nix/hosts/`: host-specific machine definitions (e.g. `zly.nix`).
- `nix/modules/`: shared system modules (`system.nix`, `hardware.nix`).
- `nix/home/default.nix`: Home Manager entrypoint (packages, Niri keybindings).
- `nix/home/configs/`: app configs — Ghostty, Foot, Tmux, Zellij, Waybar, Fuzzel, Wlogout, Yazi, shell, fcitx5, etc.
- `scripts/`: install/bootstrap helpers (for Live ISO and setup workflows).
- Docs: `KEYBINDINGS.md`, `NIX-COMMANDS.md`.

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

## Coding Style & Naming Conventions
- Format Nix code with `nixpkgs-fmt` before review.
- Keep module boundaries clear: host-specific logic in `nix/hosts`, reusable logic in `nix/modules`.
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

## Security & Configuration Tips
- Do not commit new secrets (tokens, private keys, plaintext credentials). If rotating password hashes in `flake.nix`, treat them as sensitive changes and review carefully.
- Treat disk/install scripts as destructive unless verified (`scripts/`, disko-related flows).
