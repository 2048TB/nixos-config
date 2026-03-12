# NixOS Audit Remediation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复当前审计中确认的 6 个问题，优先恢复源码可复现性和仓库完整性，再收敛环境传播与低价值兼容层。

**Architecture:** 先解决“源码快照和本地工作树行为不一致”的问题，确保干净 checkout、raw flake eval、仓库脚本三条路径一致。随后收敛 greetd 会话环境传播，最后处理文档与 PAM/keyring 的低优先级清理，避免再次出现实现、脚本、文档三方漂移。

**Tech Stack:** Nix flakes, NixOS modules, Home Manager, shell admin scripts, GitHub Actions, systemd user manager, D-Bus activation

---

## Chunk 1: Source Integrity And Flake Reproducibility

### Task 1: Make `_mixins` part of the tracked source tree

**Files:**
- Modify: `nix/modules/core/default.nix`
- Modify: `nix/home/linux/default.nix`
- Add or track explicitly: `nix/modules/core/_mixins/default.nix`
- Add or track explicitly: `nix/modules/core/_mixins/README.md`
- Add or track explicitly: `nix/home/linux/_mixins/default.nix`
- Add or track explicitly: `nix/home/linux/_mixins/README.md`
- Test: `nix/hosts/nixos/_shared/checks.nix`

- [ ] **Step 1: Decide whether `_mixins` stays as a committed indirection layer**

Review:
- `nix/modules/core/default.nix`
- `nix/home/linux/default.nix`
- `nix/modules/core/_mixins/default.nix`
- `nix/home/linux/_mixins/default.nix`

Decision rule:
- If `_mixins` is now the intended stable entrypoint, commit the files and keep imports as-is.
- If `_mixins` is transitional only, delete the indirection and import the concrete file list directly from tracked paths.

Expected output:
- A clear single-source import path with no dependency on untracked files.

- [ ] **Step 2: Add a failing reproducibility check before changing implementation**

Add one eval/build-style check that fails if:
- `git ls-files --error-unmatch nix/modules/core/_mixins/default.nix` fails, or
- `git ls-files --error-unmatch nix/home/linux/_mixins/default.nix` fails, or
- raw flake eval cannot see the module entrypoint on a clean source snapshot.

Suggested verification command:

```bash
git ls-files --error-unmatch nix/modules/core/_mixins/default.nix
git ls-files --error-unmatch nix/home/linux/_mixins/default.nix
```

Expected before fix:
- At least one command fails.

- [ ] **Step 3: Implement the minimal source-integrity fix**

Implementation options:
- Preferred: track `_mixins` files in Git and keep current architecture.
- Alternative: remove `_mixins` indirection and inline the existing import lists into the main `default.nix` files.

Constraints:
- Do not introduce another generated or ignored path as the new import root.
- Keep import lists deterministic and human-auditable.

- [ ] **Step 4: Add an explicit regression guard**

Extend repo checks so a future untracked import root is caught by CI or local checks.

Recommended locations:
- `nix/scripts/admin/repo-check.sh`
- `nix/scripts/tests/test-safety.sh`
- `nix/hosts/nixos/_shared/checks.nix`

What to assert:
- The import entrypoints used by top-level modules are committed files.
- Raw prepared-flake and raw repository flake do not diverge because of untracked code.

- [ ] **Step 5: Verify on both raw and prepared flake paths**

Run:

```bash
nix --extra-experimental-features 'nix-command flakes' eval .#nixosConfigurations.zly.config.system.stateVersion
bash -lc 'source nix/scripts/admin/common.sh; prepare_flake_repo_path .; nix eval --raw "path:$PREPARED_FLAKE_REPO#nixosConfigurations.zly.config.system.stateVersion"'
just eval-tests
just repo-check
```

Expected:
- Both eval paths succeed.
- No behavior difference caused by untracked files.

---

### Task 2: Stop `prepare_flake_repo_path` from hiding source-tree problems

**Files:**
- Modify: `nix/scripts/admin/common.sh`
- Modify: `nix/scripts/admin/flake-check.sh`
- Modify: `nix/scripts/admin/eval-tests.sh`
- Modify: `nix/scripts/admin/repo-check.sh`
- Test: `nix/scripts/tests/test-safety.sh`
- Docs: `docs/ENV-USAGE.md`
- Docs: `docs/CI.md`

- [ ] **Step 1: Write down the intended contract of `prepare_flake_repo_path`**

Document the exact purpose:
- It exists only to exclude unreadable local secrets from read-only flake operations.
- It must not silently widen source visibility beyond what flake/Git would normally include.

Reference docs:
- Nix flake source semantics
- local Git-backed source inclusion behavior

- [ ] **Step 2: Add a failing shell test for the current masking behavior**

Create a regression test that:
- prepares a filtered repo,
- confirms unreadable `.keys/` are excluded,
- confirms required tracked files remain present,
- and confirms the helper does not paper over missing tracked-source integrity.

Expected before fix:
- The helper copies untracked `_mixins`, so the test should fail if written correctly.

- [ ] **Step 3: Narrow the helper to the minimum safe behavior**

Preferred implementation shape:
- Keep filtering `.keys/`, `.git/`, transient outputs, and local agent metadata.
- Avoid copying untracked code that raw flake evaluation would not see.

Possible approaches:
- Use `git ls-files` as the copy source when inside a Git repo.
- Or enforce that any file needed by flake eval is tracked before helper use.

Selection criteria:
- Correctness and reproducibility over convenience.
- Preserve current “read-only eval works without readable `.keys`” guarantee.

- [ ] **Step 4: Align all repo scripts and docs to the same contract**

Update:
- `nix/scripts/admin/flake-check.sh`
- `nix/scripts/admin/eval-tests.sh`
- `nix/scripts/admin/repo-check.sh`
- `docs/ENV-USAGE.md`
- `docs/CI.md`

So that:
- local manual commands use the same prepared-flake guidance as scripts,
- heavy CI docs describe when raw `nix flake check --all-systems` is valid,
- and local commands stop recommending raw `path:$REPO#...` when `.keys` may be unreadable.

- [ ] **Step 5: Verify raw-vs-prepared parity**

Run:

```bash
bash -lc 'source nix/scripts/admin/common.sh; prepare_flake_repo_path .; printf "%s\n" "$PREPARED_FLAKE_REPO"'
nix --extra-experimental-features 'nix-command flakes' flake check --all-systems . || true
bash nix/scripts/admin/flake-check.sh
just repo-check
```

Expected:
- Scripted path succeeds.
- Raw path either succeeds too, or docs now clearly explain why local users must use the prepared path.
- No hidden dependency on untracked files remains.

---

## Chunk 2: Session Environment Consistency

### Task 3: Unify greetd session, systemd user, and D-Bus activation environments

**Files:**
- Modify: `nix/modules/core/services.nix`
- Review: `nix/home/linux/session.nix`
- Review: `nix/home/linux/desktop.nix`
- Test: `nix/hosts/nixos/_shared/checks.nix`

- [ ] **Step 1: Enumerate which HM session variables are required outside interactive shells**

Inspect:
- `nix/home/linux/session.nix`
- `nix/home/base/default.nix`
- `nix/home/linux/desktop.nix`

Classify variables into:
- Must propagate to `systemd --user` and D-Bus activation
- Shell-only or dev-tool-only
- Should stay local to HM profile init

Start with these candidates:
- `INPUT_METHOD`
- `GTK_IM_MODULE`
- `QT_IM_MODULE`
- `XMODIFIERS`
- `SDL_IM_MODULE`
- `XDG_CURRENT_DESKTOP`
- `XDG_SESSION_DESKTOP`
- `NIXOS_OZONE_WL`
- `QT_QPA_PLATFORMTHEME`
- `NIX_XDG_DESKTOP_PORTAL_DIR`

- [ ] **Step 2: Add a failing eval-level regression check**

Create checks that fail if:
- the greetd wrapper stops sourcing HM session vars, or
- required GUI/session activation variables are no longer imported into `systemd --user` / D-Bus.

Recommended assertion style:
- inspect the generated wrapper store script content,
- assert the expected variable names are present exactly once,
- avoid checking incidental formatting.

- [ ] **Step 3: Implement the minimal propagation fix**

Preferred behavior:
- Keep the user manager environment lean, per systemd guidance.
- Import only the minimal GUI/session variables needed by D-Bus-activated and user services.
- Do not blindly `--all` import the full shell environment.

Likely implementation:
- extend the existing explicit variable list in `nix/modules/core/services.nix`,
- keep dev-only variables like `OPENSSL_*`, `BUN_*`, `UV_*`, `GOPATH` out of activation environments.

- [ ] **Step 4: Verify with generated config inspection**

Run:

```bash
bash -lc 'source nix/scripts/admin/common.sh; prepare_flake_repo_path .; nix eval --raw "path:$PREPARED_FLAKE_REPO#nixosConfigurations.zly.config.services.greetd.settings.default_session.command"'
bash -lc 'source nix/scripts/admin/common.sh; prepare_flake_repo_path .; nix eval --json "path:$PREPARED_FLAKE_REPO#nixosConfigurations.zly.config.home-manager.users.z.home.sessionVariables"'
just eval-tests
```

Expected:
- Wrapper still uses a system-owned store script.
- Required GUI variables are explicitly imported.
- No bulk environment import is introduced.

---

## Chunk 3: Low-Value Compatibility Layers

### Task 4: Reassess `pam.services.passwd.enableGnomeKeyring`

**Files:**
- Modify: `nix/modules/core/security.nix`
- Test: `nix/hosts/nixos/_shared/checks.nix`
- Docs: `docs/README.md` or nearest security/session doc if behavior changes materially

- [ ] **Step 1: Confirm the desired password-management model**

Use current facts:
- `users.mutableUsers = false`
- passwords come from `sops` secrets
- login path is greetd + graphical session

Decide whether local `passwd` is:
- intentionally supported as a meaningful flow, or
- merely transient and not worth keyring integration.

- [ ] **Step 2: If `passwd` is not a supported long-term flow, remove the PAM hook**

Minimal implementation:
- keep `pam.services.greetd.enableGnomeKeyring = true`
- drop only `pam.services.passwd.enableGnomeKeyring`

Alternative if you want to keep it:
- add a short comment explaining why a declarative-user system still needs keyring unlock on `passwd`.

- [ ] **Step 3: Add a regression check matching the decision**

If removed:
- assert `config.security.pam.services.passwd.enableGnomeKeyring` is false or unset.

If kept:
- assert a comment or rationale exists in nearby docs or module comments so future cleanup does not re-open the question.

- [ ] **Step 4: Verify no login-chain regression**

Run:

```bash
just eval-tests
just repo-check
```

Expected:
- greetd keyring integration remains intact.
- only the `passwd` compatibility branch changes.

---

## Chunk 4: Documentation And Workflow Synchronization

### Task 5: Make manual docs, local scripts, and CI descriptions agree

**Files:**
- Modify: `docs/ENV-USAGE.md`
- Modify: `docs/CI.md`
- Modify: `.github/workflows/ci-heavy.yml` if behavior itself changes
- Review: `nix/scripts/admin/common.sh`
- Review: `nix/scripts/admin/flake-check.sh`
- Review: `nix/scripts/admin/repo-check.sh`

- [ ] **Step 1: Replace raw manual examples that are unsafe in this repo**

Update examples that currently assume:
- raw `path:$REPO#...` always works locally
- raw `nix flake check --all-systems` is the preferred local path

Replace with:
- `just eval-tests`
- `bash nix/scripts/admin/flake-check.sh`
- or explicit `prepare_flake_repo_path`-based examples where raw flake refs are still needed

- [ ] **Step 2: Distinguish local guidance from GitHub Actions guidance**

Document clearly:
- local repo may contain unreadable `.keys/main.agekey`
- repo scripts intentionally prepare a filtered flake copy
- GitHub Actions on a clean checkout may run raw `nix flake check --all-systems`

- [ ] **Step 3: Add one documentation consistency check if practical**

Low-cost options:
- shell test grepping for raw `path:$REPO#nixosConfigurations` snippets in docs that should no longer appear
- shell test ensuring docs mention `prepare_flake_repo_path` or the wrapper scripts where required

- [ ] **Step 4: Run the highest-signal verification**

Run:

```bash
just eval-tests
bash nix/scripts/admin/flake-check.sh
just repo-check
```

Expected:
- docs and scripts point to the same safe local workflow.
- CI description matches actual workflow behavior.

---

## Execution Notes

- Fix order matters:
  1. Task 1
  2. Task 2
  3. Task 3
  4. Task 4
  5. Task 5

- Task 1 and Task 2 should land before any broad cleanup, otherwise local checks may continue to hide source-integrity bugs.
- Task 3 should stay conservative: import only the minimum GUI/session variables justified by actual activation paths.
- Task 4 is intentionally lowest-risk and may be dropped from the first implementation batch if the team wants to minimize behavioral surface area.

## Verification Matrix

Run after each chunk:

```bash
just eval-tests
```

Run after Chunk 1 and Chunk 4:

```bash
just repo-check
```

Run when touching flake/script behavior:

```bash
bash nix/scripts/admin/flake-check.sh
bash -lc 'source nix/scripts/admin/common.sh; prepare_flake_repo_path .; nix eval --raw "path:$PREPARED_FLAKE_REPO#nixosConfigurations.zly.config.system.stateVersion"'
```

Run when touching session-wrapper behavior:

```bash
bash -lc 'source nix/scripts/admin/common.sh; prepare_flake_repo_path .; nix eval --raw "path:$PREPARED_FLAKE_REPO#nixosConfigurations.zly.config.services.greetd.settings.default_session.command"'
bash -lc 'source nix/scripts/admin/common.sh; prepare_flake_repo_path .; nix eval --json "path:$PREPARED_FLAKE_REPO#nixosConfigurations.zly.config.home-manager.users.z.home.sessionVariables"'
```

## Risks And Rollback

- Biggest risk: tightening `prepare_flake_repo_path` may surface previously hidden source-tree issues in local workflows. This is desired, but rollout should happen together with Task 1.
- Secondary risk: changing session environment propagation can break D-Bus-activated desktop apps if the propagated variable set is too small.
- Rollback strategy:
  - revert the chunk that changed behavior,
  - keep regression tests that exposed the issue if they are still valid,
  - do not roll back documentation-only clarifications unless they became inaccurate.
