# NixOS Config Streamlining Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不削弱多主机显式边界的前提下，消除当前仓库中仍然存在的重复校验、重复常量和重复文档事实源。

**Architecture:** 本轮只处理“当前确实重复且收益明确”的部分：host eval checks、registry 校验 helper、cache/portal 常量事实源、文档入口重叠、未接线脚本。保留每台主机显式的 `default.nix` / `hardware.nix` / `disko.nix` 和 `home/linux` 的模块拆分，不做广义 DRY 重构。

**Tech Stack:** Nix flakes, NixOS module system, Home Manager, nix-darwin, just, repo-check, eval checks, shell tests

---

## Status

- 2026-03-11：host-local `checks.nix` 已删除，shared checks 已接管默认装配
- 2026-03-11：registry 校验 helper、cache 共享常量、portal 归属、文档职责、`rebuild-auto.sh` 清理均已落地
- 本计划保留为执行记录；若条目仍引用已删除文件，以当前代码和 README 为准

## Scope And Non-Goals

- In scope:
  - 精简重复的 host eval check 包装
  - 收敛 NixOS/Darwin registry 校验重复逻辑
  - 让 cache / portal 常量只保留一个事实源
  - 收敛文档入口的双重事实源
  - 处理未接线或低价值脚本入口
- Out of scope:
  - 不合并每台主机的 `default.nix` / `hardware.nix` / `disko.nix`
  - 不回并 `nix/home/linux/*.nix`
  - 不改动 host 兼容性字段的显式声明方式（如 `systemStateVersion` / `homeStateVersion` / `resumeOffset`）

## File Map

- Modify: `nix/hosts/nixos/_shared/checks.nix`
- Modify: `nix/hosts/outputs/x86_64-linux/default.nix`
- Delete or simplify: `nix/hosts/nixos/zky/checks.nix`
- Delete or simplify: `nix/hosts/nixos/zly/checks.nix`
- Delete or simplify: `nix/hosts/nixos/zzly/checks.nix`
- Modify: `nix/lib/default.nix`
- Modify: `nix/lib/mkNixosHost.nix`
- Modify: `nix/lib/mkDarwinHost.nix`
- Optional create: `nix/lib/host-registry.nix`
- Optional create: `nix/lib/nix-cache.nix`
- Optional create: `nix/lib/portal.nix`
- Modify: `nix/modules/core/nix-settings.nix`
- Modify: `nix/modules/core/desktop.nix`
- Modify: `nix/home/linux/xdg.nix`
- Modify: `README.md`
- Modify: `docs/README.md`
- Modify: `docs/operations.md`
- Modify: `docs/NIX-COMMANDS.md`
- Modify: `docs/ENV-USAGE.md`
- Modify or delete: `nix/scripts/admin/rebuild-auto.sh`
- Modify: `nix/scripts/tests/test-registry-and-audit.sh`
- Modify: `nix/scripts/tests/test-ci-and-docs.sh`
- Modify: `nix/scripts/admin/repo-check.sh`

## Chunk 1: 收敛 Host Eval Check 重复

### Task 1: 让 shared checks 直接读取 host config

**Files:**
- Modify: `nix/hosts/nixos/_shared/checks.nix`
- Modify: `nix/hosts/outputs/x86_64-linux/default.nix`
- Delete or simplify: `nix/hosts/nixos/zky/checks.nix`
- Delete or simplify: `nix/hosts/nixos/zly/checks.nix`
- Delete or simplify: `nix/hosts/nixos/zzly/checks.nix`

- [ ] **Step 1: 记录当前重复前提**

Run: `diff -u nix/hosts/nixos/zky/checks.nix nix/hosts/nixos/zly/checks.nix`
Expected: 差异为空或只剩 host 文件路径差异。

- [ ] **Step 2: 为删除 wrapper 先写失败前提检查**

Run: `rg -n 'expectedLuksName|expectedResumeOffset|expectedHostProfile|expectedTrustedUsers' nix/hosts/nixos/_shared/checks.nix nix/hosts/nixos/*/checks.nix`
Expected: wrapper 与 shared 同时命中这些字段。

- [ ] **Step 3: 在 shared checks 内改为直接使用 `cfg.my.host`**

最小实现目标：
- `expectedLuksName` 默认来自 `cfg.my.host.luksName`
- `expectedResumeOffset` 默认来自 `cfg.my.host.resumeOffset`
- `expectedHostProfile` 默认仍保持 `name`
- `expectedTrustedUsers` 默认仍保持 `[ "root" ]`

- [ ] **Step 4: 调整 host outputs 的 checks 装配**

如果 host-local `checks.nix` 不再提供额外值，则在 `nix/hosts/outputs/x86_64-linux/default.nix` 中直接加载 shared checks；
如果保留 host-local 文件，则仅在存在 host 例外时才引用。

- [ ] **Step 5: 删除或最小化 3 个 host checks wrapper**

目标状态二选一：
- 直接删除 `zky` / `zly` / `zzly` 的 `checks.nix`
- 或将其缩到“仅传 host 特例值”这一层；若没有特例则不保留

- [ ] **Step 6: 运行验证**

Run: `just eval-tests`
Expected: exit code `0`

- [ ] **Step 7: 运行补充验证**

Run: `just hosts`
Expected: 仍列出 `zky`、`zly`、`zzly`、`zly-mac`

- [ ] **Step 8: Commit**

```bash
git add nix/hosts/nixos/_shared/checks.nix nix/hosts/outputs/x86_64-linux/default.nix nix/hosts/nixos/zky/checks.nix nix/hosts/nixos/zly/checks.nix nix/hosts/nixos/zzly/checks.nix
git commit -m "refactor: deduplicate nixos host eval checks"
```

### Task 2: 收敛 cache 预期常量的双重事实源

**Files:**
- Optional create: `nix/lib/nix-cache.nix`
- Modify: `nix/lib/default.nix`
- Modify: `nix/modules/core/nix-settings.nix`
- Modify: `nix/hosts/nixos/_shared/checks.nix`

- [ ] **Step 1: 识别当前双写**

Run: `rg -n 'nix-community.cachix.org|nixpkgs-wayland.cachix.org|cache.garnix.io|trusted-users|trusted-substituters' nix/modules/core/nix-settings.nix nix/hosts/nixos/_shared/checks.nix`
Expected: 同一组 cache / trusted-user 常量在两处命中。

- [ ] **Step 2: 抽取共享常量**

创建或新增一个集中位置，至少包含：
- `cacheSubstituters`
- `cacheTrustedPublicKeys`
- `trustedUsers`

- [ ] **Step 3: 更新 system 模块与 eval checks**

让 `nix-settings.nix` 与 `_shared/checks.nix` 同时引用该共享常量，而不是各自硬编码。

- [ ] **Step 4: 运行验证**

Run: `just eval-tests`
Expected: exit code `0`

- [ ] **Step 5: Commit**

```bash
git add nix/lib/default.nix nix/lib/nix-cache.nix nix/modules/core/nix-settings.nix nix/hosts/nixos/_shared/checks.nix
git commit -m "refactor: share nix cache expectations between module and eval checks"
```

## Chunk 2: 收敛 Assembly Layer 重复

### Task 3: 抽出 host registry 校验 helper

**Files:**
- Optional create: `nix/lib/host-registry.nix`
- Modify: `nix/lib/default.nix`
- Modify: `nix/lib/mkNixosHost.nix`
- Modify: `nix/lib/mkDarwinHost.nix`

- [ ] **Step 1: 固化当前重复前提**

Run: `rg -n 'allowedRegistryKeys|registryOwnedKeys|deployEnabled = hostRegistry.deployEnabled|profiles must be a list|deployPort must be a positive integer' nix/lib/mkNixosHost.nix nix/lib/mkDarwinHost.nix`
Expected: NixOS/Darwin 两边都命中相同模式。

- [ ] **Step 2: 设计最小共享接口**

helper 只负责：
- `allowedRegistryKeys`
- unknown/conflicting key 计算
- `system` / `profiles` / `deploy*` 通用断言

helper 不负责：
- NixOS 专属文件存在性断言
- Darwin 专属 bootstrap/homebrew 逻辑

- [ ] **Step 3: 在 `mkNixosHost.nix` 接入 helper**

保留 NixOS 独有部分：
- `hardware.nix` / `hardware-modules.nix` / `disko.nix` / `vars.nix` 断言
- `derivedCpuVendor` / `derivedGpuMode`

- [ ] **Step 4: 在 `mkDarwinHost.nix` 接入 helper**

保留 Darwin 独有部分：
- `nix-homebrew` bootstrap
- Darwin `vars.nix` 必需字段断言

- [ ] **Step 5: 运行验证**

Run: `just hosts && just eval-tests`
Expected: 全部通过

- [ ] **Step 6: Commit**

```bash
git add nix/lib/default.nix nix/lib/host-registry.nix nix/lib/mkNixosHost.nix nix/lib/mkDarwinHost.nix
git commit -m "refactor: share host registry validation logic"
```

## Chunk 3: 统一 Portal 事实源

### Task 4: 为 portal 配置定义单一事实源

**Files:**
- Optional create: `nix/lib/portal.nix`
- Modify: `nix/lib/default.nix`
- Modify: `nix/modules/core/desktop.nix`
- Modify: `nix/home/linux/xdg.nix`

- [ ] **Step 1: 确认 system/home 双写范围**

Run: `rg -n 'portalConfig|xdg\\.portal|extraPortals|config = portalConfig' nix/modules/core/desktop.nix nix/home/linux/xdg.nix`
Expected: `config` 与 `enable` 在两处同时命中。

- [ ] **Step 2: 决定 source of truth**

推荐规则：
- system 层只负责 `xdg.portal.enable`、`xdg.portal.xdgOpenUsePortal`
- HM 层只负责 `extraPortals` 与 `config`

如果实际测试表明更稳定的组合相反，也允许反转，但必须最终只保留一处写 `config`。

- [ ] **Step 3: 抽取共享 portal config**

如果 `portal-config.nix` 仍足够小，可直接复用；
若需要同时表达 backend 与 config，则新增 `nix/lib/portal.nix` 统一导出。

- [ ] **Step 4: 运行验证**

Run: `just eval-tests`
Expected: exit code `0`

- [ ] **Step 5: 记录未验证范围**

如果没有桌面集成测试，明确标记：
- portal FileChooser / Settings D-Bus 路径未做运行时验证

- [ ] **Step 6: Commit**

```bash
git add nix/lib/default.nix nix/lib/portal.nix nix/modules/core/desktop.nix nix/home/linux/xdg.nix
git commit -m "refactor: centralize portal configuration ownership"
```

## Chunk 4: 收敛文档双重事实源

### Task 5: 重建文档分工，避免 4 份文档重复同一命令

**Files:**
- Modify: `README.md`
- Modify: `docs/README.md`
- Modify: `docs/operations.md`
- Modify: `docs/NIX-COMMANDS.md`
- Modify: `docs/ENV-USAGE.md`
- Modify: `nix/scripts/tests/test-ci-and-docs.sh`

- [ ] **Step 1: 锁定当前重复段**

Run: `rg -n 'just hosts|just host=zly check|just host=zly switch|just eval-tests|just repo-check|just flake-check' README.md docs/README.md docs/operations.md docs/NIX-COMMANDS.md docs/ENV-USAGE.md`
Expected: 同一命令组在多份文档重复出现。

- [ ] **Step 2: 调整文档职责**

目标职责：
- `README.md`: 仓库简介 + 文档索引 + 2 到 4 条最关键入口
- `docs/README.md`: 唯一“人类主文档”
- `docs/operations.md`: 若保留，只做 1 屏运维摘要；否则并入 `docs/README.md`
- `docs/NIX-COMMANDS.md`: 只保留命令速查、flake apps、长命令说明
- `docs/ENV-USAGE.md`: 只保留按环境差异，不重复通用日常命令

- [ ] **Step 3: 清除不再准确的重复描述**

优先处理：
- `README.md` 中完整高频命令块
- `docs/operations.md` 中与主文档完全重叠的命令块
- `docs/NIX-COMMANDS.md` 中与 `docs/README.md` 一致的“常见工作流”块

- [ ] **Step 4: 更新文档测试**

修改 `nix/scripts/tests/test-ci-and-docs.sh`，使其只断言文档入口仍存在与索引关系仍成立，不再强依赖某些重复段必须存在。

- [ ] **Step 5: 运行验证**

Run: `bash nix/scripts/tests/test-ci-and-docs.sh`
Expected: exit code `0`

- [ ] **Step 6: Commit**

```bash
git add README.md docs/README.md docs/operations.md docs/NIX-COMMANDS.md docs/ENV-USAGE.md nix/scripts/tests/test-ci-and-docs.sh
git commit -m "docs: remove duplicated operational guidance"
```

## Chunk 5: 处理低价值入口

### Task 6: 明确 `rebuild-auto.sh` 的命运

**Files:**
- Modify or delete: `nix/scripts/admin/rebuild-auto.sh`
- Modify: `nix/scripts/tests/test-registry-and-audit.sh`
- Optional modify: `justfile`
- Optional modify: `nix/hosts/outputs/x86_64-linux/default.nix`
- Optional modify: `nix/hosts/outputs/aarch64-darwin/default.nix`

- [ ] **Step 1: 确认当前是否未接线**

Run: `rg -n 'rebuild-auto\\.sh' .`
Expected: 只命中脚本自身，或没有实际调用路径。

- [ ] **Step 2: 二选一**

方案 A，推荐：删除 `rebuild-auto.sh`
- 适用条件：仓库内没有调用点，且不会提供额外统一价值

方案 B：把现有入口接到它
- 适用条件：希望保留统一分发层，并愿意同步更新 tests 与调用者

- [ ] **Step 3: 更新对应测试**

如果删除脚本，则删掉或改写与其存在性相关的断言；
如果保留并接线，则为新入口补 shell regression test。

- [ ] **Step 4: 运行验证**

Run: `bash nix/scripts/tests/test-registry-and-audit.sh && bash nix/scripts/tests/test-rebuild-entrypoints.sh`
Expected: exit code `0`

- [ ] **Step 5: Commit**

```bash
git add nix/scripts/admin/rebuild-auto.sh nix/scripts/tests/test-registry-and-audit.sh justfile nix/hosts/outputs/x86_64-linux/default.nix nix/hosts/outputs/aarch64-darwin/default.nix
git commit -m "refactor: remove or wire rebuild auto entrypoint"
```

## Recommended Order

1. Chunk 1 / Task 1
2. Chunk 1 / Task 2
3. Chunk 2 / Task 3
4. Chunk 4 / Task 5
5. Chunk 5 / Task 6
6. Chunk 3 / Task 4

## Verification Matrix

- 改 `hosts` / `lib` / `modules`：`just eval-tests`
- 改 `mk*Host` / `outputs` / registry contract：`just hosts && just eval-tests`
- 改文档测试：`bash nix/scripts/tests/test-ci-and-docs.sh`
- 改 shell scripts：`bash nix/scripts/tests/test-registry-and-audit.sh && bash nix/scripts/tests/test-rebuild-entrypoints.sh`
- 最终汇总：`just repo-check`

## Risks

- `portal` 精简后最容易出现的是运行时桌面回归，而不是 eval 失败
- `registry` helper 抽取若过度，容易把 NixOS/Darwin 的差异重新隐藏掉
- 文档精简若不同时更新 shell tests，会产生“文档已改、测试仍锁旧内容”的假失败
- 删除 host-local `checks.nix` 前，必须确认未来没有计划在 host 级加入例外断言

## Rollback Guidance

- 每个 Chunk 单独提交；不要跨 Chunk 混合提交
- 若 `Task 4` 触发桌面回归，优先回滚该单独提交，不影响前面的结构精简
- 若文档职责调整后引起争议，保留文件但删正文重复段，比直接删除文件更容易回退
