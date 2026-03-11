# Hardware Layer Review And Rationalization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保留当前主机显式硬件边界的前提下，清理硬件层仅剩的低价值薄包装，收紧 helper 默认值，并明确哪些选项应留在 hardware layer、哪些应迁移到更通用的 system layer。

**Architecture:** 当前硬件层的主结构保持不变：`hardware-modules.nix` 继续作为 `nixos-hardware` 事实入口，`hardware.nix` 继续作为主机硬件装配入口，`disko.nix` 继续作为主机磁盘布局入口。本轮只处理三类问题：无信息增量的 host-local workaround wrapper、`mkNixosHardwareModule` 的偏宽松默认值、以及 `fwupd` / `bluetooth` 这类“设备服务基线”是否留在 hardware layer 的归属说明。

**Tech Stack:** Nix flakes, NixOS module system, nixos-hardware, disko, just, eval checks, repo-check

---

## Status

- 2026-03-12：Chunk 1 与 Chunk 2 已落地，`zky` / `zly` / `zzly` 现均直接 import `_shared/hardware-workarounds-common.nix`
- 2026-03-12：`mkNixosHardwareModule` 已收紧为仅在 CPU vendor 明确时才写 microcode 默认值
- 2026-03-12：文档层采用保守结论，`bluetooth` / `fwupd` 仍留在 `nix/modules/core/hardware.nix`
- 本计划后续步骤保留为执行记录；若与当前仓库状态冲突，以代码和 README 为准

## Scope And Non-Goals

- In scope:
  - 删除没有主机增量的 `hardware-workarounds.nix` wrapper
  - 审核 `mkNixosHardwareModule` 的 `initrd` / firmware / microcode 默认值
  - 明确 `fwupd` / `bluetooth` 的归属边界，并按结论同步文档
  - 保持 `hardware-modules.nix` 与 `disko.nix` 的现有显式结构
- Out of scope:
  - 不合并每台主机的 `default.nix` / `hardware.nix` / `disko.nix`
  - 不改写 `disko` 的共享布局
  - 不把 `nixos-hardware` 模块名从 `hardware-modules.nix` 动态推导
  - 不新增硬件自动探测或生成式流程

## File Map

- Modify: `nix/hosts/nixos/zky/hardware.nix`
- Modify: `nix/hosts/nixos/zzly/hardware.nix`
- Delete: `nix/hosts/nixos/zky/hardware-workarounds.nix`
- Delete: `nix/hosts/nixos/zzly/hardware-workarounds.nix`
- Modify: `nix/lib/default.nix`
- Modify: `nix/modules/core/hardware.nix`
- Modify: `nix/hosts/README.md`
- Modify: `nix/hosts/nixos/README.md`
- Optional modify: `docs/architecture.md`

## Chunk 1: 删除无信息增量的 workaround wrapper

### Task 1: 让 `zky` / `zzly` 直接 import shared workaround

**Files:**
- Modify: `nix/hosts/nixos/zky/hardware.nix`
- Modify: `nix/hosts/nixos/zzly/hardware.nix`
- Delete: `nix/hosts/nixos/zky/hardware-workarounds.nix`
- Delete: `nix/hosts/nixos/zzly/hardware-workarounds.nix`

- [ ] **Step 1: 固化当前重复前提**

Run: `diff -u nix/hosts/nixos/zky/hardware-workarounds.nix nix/hosts/nixos/zzly/hardware-workarounds.nix`
Expected: 差异为空。

- [ ] **Step 2: 确认 `zly` 仍保留主机增量**

Run: `sed -n '1,120p' nix/hosts/nixos/zly/hardware-workarounds.nix`
Expected: 除 shared import 外，仍包含 `initrd` timeout override。

- [ ] **Step 3: 修改 `zky` / `zzly` 的 `hardware.nix`**

最小实现目标：
- 将 `extraImports = [ ./hardware-workarounds.nix ];`
- 改为 `extraImports = [ ../_shared/hardware-workarounds-common.nix ];`

- [ ] **Step 4: 删除两个薄包装文件**

删除：
- `nix/hosts/nixos/zky/hardware-workarounds.nix`
- `nix/hosts/nixos/zzly/hardware-workarounds.nix`

- [ ] **Step 5: 运行验证**

Run: `just eval-tests`
Expected: exit code `0`

- [ ] **Step 6: 运行补充验证**

Run: `just repo-check`
Expected: exit code `0`

- [ ] **Step 7: Commit**

```bash
git add nix/hosts/nixos/zky/hardware.nix nix/hosts/nixos/zzly/hardware.nix nix/hosts/nixos/zky/hardware-workarounds.nix nix/hosts/nixos/zzly/hardware-workarounds.nix
git commit -m "refactor: remove redundant hardware workaround wrappers"
```

## Chunk 2: 收紧 `mkNixosHardwareModule` 默认值

### Task 2: 审核 `initrd` / firmware / microcode 的 helper 责任

**Files:**
- Modify: `nix/lib/default.nix`
- Test: `just eval-tests`

- [ ] **Step 1: 固化当前 helper 行为**

Run: `sed -n '255,282p' nix/lib/default.nix`
Expected: 能看到 `availableKernelModules`、`enableRedistributableFirmware`、`cpu.amd.updateMicrocode`、`cpu.intel.updateMicrocode` 的默认值。

- [ ] **Step 2: 评估 `availableKernelModules` 是否仍应保留统一基线**

判定规则：
- 如果当前车队仍全部是通用 x86_64 NVMe 机器，则保留统一基线
- 如果已有或即将加入非同类主机，则把该默认值移到 host-specific 或 profile-specific 层

本轮默认建议：
- 保留统一 `availableKernelModules`
- 但在 README / architecture 文档中明确它是“车队基线”，不是自动探测结果

- [ ] **Step 3: 收紧 microcode fallback**

最小实现目标：
- 避免 `derivedCpuVendor = "auto"` 时同时偏向开启 AMD / Intel 两边的 microcode 默认值
- 推荐改法：仅在 `cpuVendor == "amd"` 或 `cpuVendor == "intel"` 时分别 `mkDefault true`
- `cpuVendor == "auto"` 时让两边都不主动写默认值，交给更具体模块决定

- [ ] **Step 4: 运行验证**

Run: `just eval-tests`
Expected: exit code `0`

- [ ] **Step 5: 运行补充验证**

Run: `just hosts`
Expected: 仍列出 `zky`、`zly`、`zzly`、`zly-mac`

- [ ] **Step 6: Commit**

```bash
git add nix/lib/default.nix
git commit -m "refactor: tighten hardware helper defaults"
```

## Chunk 3: 明确 `hardware layer` 与 `device service baseline` 的边界

### Task 3: 决定 `fwupd` / `bluetooth` 是否继续留在 `nix/modules/core/hardware.nix`

**Files:**
- Modify: `nix/modules/core/hardware.nix`
- Modify: `nix/hosts/README.md`
- Modify: `nix/hosts/nixos/README.md`
- Optional modify: `docs/architecture.md`

- [ ] **Step 1: 固化当前边界**

Run: `sed -n '1,120p' nix/modules/core/hardware.nix`
Expected: `hardware.graphics`、`hardware.nvidia`、`hardware.bluetooth`、`services.fwupd.enable` 都在同一个模块中。

- [ ] **Step 2: 做边界判定**

判定规则：
- 如果选项直接描述驱动、firmware、显卡、microcode、initrd 装配，留在 `hardware.nix`
- 如果选项更接近“桌面/设备服务基线”，可迁移到更通用的 core 模块

建议结论二选一：
- 保守方案：`bluetooth` / `fwupd` 继续留在 `hardware.nix`，只补文档说明“该模块也承载设备服务基线”
- 稍收敛方案：把 `fwupd.enable` 与 `hardware.bluetooth.enable` 迁到更贴近 desktop/base 的模块，只让 `hardware.nix` 保留驱动与固件相关项

- [ ] **Step 3: 按结论做最小改动**

限制：
- 不同时改动多个 core 模块边界
- 如果迁移，只迁 `fwupd` 和 `bluetooth`，不要连带清理无关项

- [ ] **Step 4: 同步文档**

至少更新：
- `nix/hosts/README.md`
- `nix/hosts/nixos/README.md`

需要表达清楚：
- `hardware-modules.nix` 是 `nixos-hardware` 事实入口
- `hardware.nix` 负责什么，不负责什么
- shared workaround 何时可以直接 import，何时必须保留 host-local wrapper

- [ ] **Step 5: 运行验证**

Run: `just eval-tests && just repo-check`
Expected: 全部通过

- [ ] **Step 6: 记录未验证范围**

必须明确标记：
- 未做实际蓝牙控制器上电 / rfkill 恢复手测
- 未做真实硬件 cold boot / suspend-resume / PRIME runtime 手测

- [ ] **Step 7: Commit**

```bash
git add nix/modules/core/hardware.nix nix/hosts/README.md nix/hosts/nixos/README.md docs/architecture.md
git commit -m "docs: clarify hardware layer boundaries"
```

## Chunk 4: 最终收尾与一致性检查

### Task 4: 做一次硬件层专项验收

**Files:**
- Review only: `nix/lib/default.nix`
- Review only: `nix/modules/core/hardware.nix`
- Review only: `nix/hosts/nixos/_shared/hardware-workarounds-common.nix`
- Review only: `nix/hosts/nixos/*/hardware*.nix`
- Review only: `nix/hosts/nixos/*/disko.nix`

- [ ] **Step 1: 检查 README 与代码边界一致**

Run: `rg -n 'hardware.nix|hardware-modules.nix|disko.nix|hardware-workarounds-common|fwupd|bluetooth' nix/hosts/README.md nix/hosts/nixos/README.md docs/architecture.md nix/modules/core/hardware.nix nix/lib/default.nix`
Expected: 文档描述和代码归属不冲突。

- [ ] **Step 2: 运行最终验证**

Run: `just hosts && just eval-tests && just repo-check`
Expected: 全部通过

- [ ] **Step 3: Push**

```bash
git push origin HEAD
```
