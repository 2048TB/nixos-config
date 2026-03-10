# Directory Structure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce directory nesting and unify naming without changing repository behavior.

**Architecture:** Keep the existing `flake -> hosts -> shared platform modules` skeleton, but move scattered files into clearer paths. Host-specific Home Manager modules will live with their host definitions, and generic shared code will move out of `common/` into a single `shared/` directory.

**Tech Stack:** Nix flakes, NixOS modules, nix-darwin, Home Manager, shell scripts

---

### Task 1: Rename shared/common paths

**Files:**
- Move: `nix/common/host-validation.nix` -> `nix/shared/host-validation.nix`
- Move: `nix/common/render-hosts-doc.nix` -> `nix/shared/render-hosts-doc.nix`
- Modify: `nix/nixos/base.nix`
- Modify: `nix/darwin/base.nix`
- Modify: `scripts/generate-hosts-doc.sh`

**Step 1:** Update imports and script references to the new `nix/shared/` path.

**Step 2:** Run `./scripts/generate-hosts-doc.sh --check`.

### Task 2: Unify Home software naming

**Files:**
- Move: `nix/home/package-groups.nix` -> `nix/home/software.nix`
- Modify: `nix/home/base.nix`
- Modify: `README.md`
- Modify: `docs/operations.md`

**Step 1:** Rename the module file and update references.

**Step 2:** Keep behavior identical; only change naming and import paths.

### Task 3: Co-locate host-specific Home Manager modules

**Files:**
- Move: `nix/hosts/darwin/mbp-work/home.nix` -> `nix/hosts/darwin/mbp-work/system.nix`
- Move: `nix/home/hosts/mbp-work.nix` -> `nix/hosts/darwin/mbp-work/home.nix`
- Modify: `nix/hosts/darwin/mbp-work/default.nix`
- Modify: `nix/home/base.nix`
- Modify: `flake.nix`
- Delete: `nix/home/hosts/mbp-work.nix`

**Step 1:** Pass `platform` into Home Manager special args.

**Step 2:** Resolve host-specific HM modules from `nix/hosts/<platform>/<host>/home.nix`.

**Step 3:** Update Darwin host imports to use `system.nix`.

### Task 4: Verify behavior

**Files:**
- Verify: repository root

**Step 1:** Run `./scripts/repo-check.sh`.

**Step 2:** Run `nix build --dry-run .#nixosConfigurations.zly.config.system.build.toplevel`.

**Step 3:** Run `nix build --dry-run '.#darwinConfigurations.mbp-work.system'`.

**Step 4:** Run `nix build --dry-run '.#homeConfigurations."z@mbp-work".activationPackage'`.
