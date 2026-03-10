# Secrets Structure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce secrets-related nesting by moving host-specific secret modules into host directories and unifying shared module naming.

**Architecture:** Keep the current `nix/nixos/roles/secrets.nix` orchestration module, but resolve host-specific secret modules from `nix/hosts/nixos/<host>/secrets.nix`. Rename the shared secrets module to `shared.nix` to match the repo-wide `shared` naming convention.

**Tech Stack:** Nix flakes, NixOS modules, sops-nix

---

### Task 1: Unify shared secrets naming

**Files:**
- Move: `nix/nixos/secrets/common.nix` -> `nix/nixos/secrets/shared.nix`
- Modify: `nix/nixos/roles/secrets.nix`

**Step 1:** Rename the shared module file.

**Step 2:** Update the role module to import `shared.nix`.

### Task 2: Co-locate host-specific secret modules

**Files:**
- Move: `nix/nixos/secrets/hosts/zky.nix` -> `nix/hosts/nixos/zky/secrets.nix`
- Move: `nix/nixos/secrets/hosts/zly.nix` -> `nix/hosts/nixos/zly/secrets.nix`
- Move: `nix/nixos/secrets/hosts/zzly.nix` -> `nix/hosts/nixos/zzly/secrets.nix`
- Modify: `nix/nixos/roles/secrets.nix`
- Delete: `nix/nixos/secrets/hosts/`

**Step 1:** Move each host file next to its host definition.

**Step 2:** Update the orchestrator path lookup.

### Task 3: Sync docs and verify

**Files:**
- Modify: `docs/operations.md`

**Step 1:** Update the host-only secrets path in docs.

**Step 2:** Run `./scripts/repo-check.sh`.

**Step 3:** Run `nix build --dry-run .#nixosConfigurations.zly.config.system.build.toplevel`.
