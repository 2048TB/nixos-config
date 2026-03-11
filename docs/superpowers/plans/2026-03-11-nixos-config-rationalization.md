# NixOS Config Rationalization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不破坏现有多主机结构的前提下，消除 registry/host/doc 中的死字段、重复模板和文档双重事实源。

**Architecture:** 先清理“无运行时价值但增加维护面的字段”，再把 host checks 与 host docs 收敛到单一事实源，最后只在收益明确时做轻量模块拆分。保留 host 目录的显式入口和 system/home 分层，不做大重构。

**Tech Stack:** Nix flakes, NixOS module system, Home Manager, nix-darwin, just, repo-check/eval-tests

---

## File Map

- Modify: `nix/lib/mkNixosHost.nix`
- Modify: `nix/lib/mkDarwinHost.nix`
- Modify: `nix/hosts/registry/systems.schema.json`
- Modify: `nix/hosts/registry/systems.toml`
- Modify: `nix/modules/core/options.nix`
- Modify: `nix/lib/host-meta.nix`
- Modify: `nix/hosts/nixos/_shared/checks.nix`
- Modify: `nix/hosts/nixos/zky/checks.nix`
- Modify: `nix/hosts/nixos/zly/checks.nix`
- Modify: `nix/hosts/nixos/zzly/checks.nix`
- Modify: `nix/hosts/README.md`
- Modify: `nix/hosts/nixos/README.md`
- Optional modify: `nix/home/linux/default.nix`
- Optional create: `nix/home/linux/session.nix`
- Optional create: `nix/home/linux/files.nix`

## Chunk 1: 最小 Diff，先删死配置面

### Task 1: 清理 `configRepoPath` 的伪扩展点

**Files:**
- Modify: `nix/lib/mkNixosHost.nix`
- Modify: `nix/lib/mkDarwinHost.nix`
- Modify: `nix/hosts/registry/systems.schema.json`
- Modify: `nix/hosts/README.md`

- [ ] **Step 1: 写一个失败前提检查**

Run: `rg -n 'configRepoPath' nix`
Expected: 命中 registry schema、mk*Host 与真实使用点。

- [ ] **Step 2: 删掉 registry 层允许但未消费的字段**

在 `allowedRegistryKeys` 中移除 `configRepoPath`，同步从 `systems.schema.json` 删除该 schema 字段。

- [ ] **Step 3: 更新文档**

从 `nix/hosts/README.md` 的 registry 字段说明中删掉 `configRepoPath`，避免误导后续新增主机时继续填该字段。

- [ ] **Step 4: 运行最小验证**

Run: `just hosts`
Expected: 仍能列出 `zky`、`zly`、`zzly`、`zly-mac`

- [ ] **Step 5: 运行 eval 验证**

Run: `just eval-tests`
Expected: 退出码 `0`

- [ ] **Step 6: 提交**

```bash
git add nix/lib/mkNixosHost.nix nix/lib/mkDarwinHost.nix nix/hosts/registry/systems.schema.json nix/hosts/README.md
git commit -m "refactor: drop unused configRepoPath registry field"
```

### Task 2: 清理 `formFactor` / `profiles` 的双轨表达

**Decision Gate:**
- 如果近期确实要按 `formFactor` 做 deploy/filter/UI，则保留 `formFactor`，本任务跳过。
- 如果没有已知消费方，则删除 `formFactor`，以 `profiles` 作为唯一高层机器形态表达。

**Files:**
- Modify: `nix/lib/mkNixosHost.nix`
- Modify: `nix/lib/mkDarwinHost.nix`
- Modify: `nix/hosts/registry/systems.schema.json`
- Modify: `nix/hosts/registry/systems.toml`
- Modify: `nix/hosts/README.md`

- [ ] **Step 1: 确认没有运行时消费**

Run: `rg -n 'formFactor' nix`
Expected: 只命中 schema、registry、README、测试样例，不命中运行时模块逻辑。

- [ ] **Step 2: 从 registry contract 中删除 `formFactor`**

同步更新 `mkNixosHost.nix` / `mkDarwinHost.nix` 的 required/assert 逻辑，避免继续把它当 required key。

- [ ] **Step 3: 精简 registry 数据**

从 `nix/hosts/registry/systems.toml` 删除各主机的 `formFactor`。

- [ ] **Step 4: 更新 README 说明**

将“Platform: system/formFactor/gpuMode”改成“Platform: system/gpuMode；profile 使用 `profiles`”。

- [ ] **Step 5: 运行验证**

Run: `just hosts && just eval-tests`
Expected: 全部通过

- [ ] **Step 6: 提交**

```bash
git add nix/lib/mkNixosHost.nix nix/lib/mkDarwinHost.nix nix/hosts/registry/systems.schema.json nix/hosts/registry/systems.toml nix/hosts/README.md
git commit -m "refactor: remove unused formFactor from host registry"
```

## Chunk 2: 中等整理，收敛重复事实源

### Task 3: 让 `profiles` 与 `roles` 一轴一职责

**Target Rule:**
- `profiles`: `desktop` / `laptop` / `server`
- `roles`: `gaming` / `vpn` / `virt` / `container`
- 不再使用 `roles.desktop`

**Files:**
- Modify: `nix/lib/host-meta.nix`
- Modify: `nix/modules/core/options.nix`
- Modify: `nix/hosts/nixos/zky/vars.nix`
- Modify: `nix/hosts/nixos/zly/vars.nix`
- Modify: `nix/hosts/nixos/zzly/vars.nix`
- Modify: `nix/hosts/README.md`
- Modify: `nix/hosts/nixos/README.md`

- [ ] **Step 1: 写失败前提检查**

Run: `rg -n '"desktop"' nix/hosts/nixos/*/vars.nix nix/lib/host-meta.nix nix/modules/core/options.nix`
Expected: 同时命中 `roles` 和 `profiles` 相关逻辑。

- [ ] **Step 2: 修改角色推导**

在 `nix/lib/host-meta.nix` 中移除 `enableFlatpak = hasRole "desktop"`，改为由 `config.my.profiles.desktop` 在使用点决定。

- [ ] **Step 3: 修改使用方**

将依赖 `enableFlatpak` 的逻辑改为依赖 `config.my.profiles.desktop`，避免 role/profile 混用。

- [ ] **Step 4: 精简 host vars**

把每台 `vars.nix` 的 `roles` 列表中的 `"desktop"` 删除，仅在 `profiles` 或 registry 中表达桌面属性。

- [ ] **Step 5: 更新模板文档**

更新 `nix/hosts/README.md` 与 `nix/hosts/nixos/README.md` 的模板示例，明确 `roles` 不再承载 `desktop`。

- [ ] **Step 6: 运行验证**

Run: `just eval-tests`
Expected: 全部通过；若 flatpak/desktop gate 断言失败，回看 `storage.nix` 和相关 role 模块。

- [ ] **Step 7: 提交**

```bash
git add nix/lib/host-meta.nix nix/modules/core/options.nix nix/hosts/nixos/zky/vars.nix nix/hosts/nixos/zly/vars.nix nix/hosts/nixos/zzly/vars.nix nix/hosts/README.md nix/hosts/nixos/README.md
git commit -m "refactor: separate host profiles from roles"
```

### Task 4: 收敛 per-host checks 模板重复

**Files:**
- Modify: `nix/hosts/nixos/_shared/checks.nix`
- Modify: `nix/hosts/nixos/zky/checks.nix`
- Modify: `nix/hosts/nixos/zly/checks.nix`
- Modify: `nix/hosts/nixos/zzly/checks.nix`

- [ ] **Step 1: 先识别真正的 host 差异**

Run: `diff -u nix/hosts/nixos/zky/checks.nix nix/hosts/nixos/zly/checks.nix`
Expected: 主要差异集中在 `expectedVideoDrivers`。

- [ ] **Step 2: 把可推导值移入 shared checks**

将以下值改为 shared 内自动推导：
- `expectedHostProfile = name`
- `expectedTrustedUsers = [ "root" ]`
- `expectedDockerMode` 从 `hostVars.roles` / `dockerMode` 推导
- `cpuVendor` 从 `hardware-modules.nix` 推导

- [ ] **Step 3: 缩小 per-host 文件**

将每台 `checks.nix` 收敛成“只提供例外”，优先保留 `expectedVideoDrivers`；如果没有额外差异，允许文件仅保留最小包装。

- [ ] **Step 4: 运行高信号验证**

Run: `just eval-tests`
Expected: 全部通过

- [ ] **Step 5: 提交**

```bash
git add nix/hosts/nixos/_shared/checks.nix nix/hosts/nixos/zky/checks.nix nix/hosts/nixos/zly/checks.nix nix/hosts/nixos/zzly/checks.nix
git commit -m "refactor: deduplicate per-host eval checks"
```

### Task 5: 删掉 README 中的双重事实源

**Files:**
- Modify: `nix/hosts/nixos/README.md`
- Modify: `nix/hosts/README.md`

- [ ] **Step 1: 删除“当前三台主机参数对照表”**

从 `nix/hosts/nixos/README.md` 删掉 registry/vars/roles/hardware-modules 对照表，不再把真实主机数据抄写进 README。

- [ ] **Step 2: 保留模板与规则**

README 只保留：
- 最小模板
- 字段解释
- 新增主机步骤
- 关联真实事实源的路径

- [ ] **Step 3: 增加“真实数据看哪里”**

明确指向：
- `nix/hosts/registry/systems.toml`
- `nix/hosts/nixos/<host>/vars.nix`
- `nix/hosts/nixos/<host>/hardware-modules.nix`

- [ ] **Step 4: 验证**

Run: `nix run .#fmt -- --check` 或 `just fmt`
Expected: 文档修改不影响 Nix；若未配置文档检查则仅确认文件存在且内容正确。

- [ ] **Step 5: 提交**

```bash
git add nix/hosts/README.md nix/hosts/nixos/README.md
git commit -m "docs: remove duplicated host facts from README"
```

## Chunk 3: 激进清理，只在前两档稳定后做

### Task 6: 只抽共享默认值，不隐藏 compatibility 边界

**Files:**
- Create: `nix/hosts/nixos/_shared/vars-common.nix`
- Modify: `nix/hosts/nixos/zky/vars.nix`
- Modify: `nix/hosts/nixos/zly/vars.nix`
- Modify: `nix/hosts/nixos/zzly/vars.nix`
- Optional modify: `nix/hosts/darwin/zly-mac/vars.nix`

- [ ] **Step 1: 只抽稳定共享值**

放入 shared 的仅限：
- `username = "z"`
- `timezone = "Asia/Shanghai"`
- 默认 app toggles
- 公共 `diskDevice` env fallback 逻辑

- [ ] **Step 2: 明确保留显式值**

继续在每台主机显式保留：
- `systemStateVersion`
- `homeStateVersion`
- `resumeOffset`
- `gpuMode`
- bus IDs
- `roles`

- [ ] **Step 3: 运行验证**

Run: `just eval-tests`
Expected: 全部通过

- [ ] **Step 4: 提交**

```bash
git add nix/hosts/nixos/_shared/vars-common.nix nix/hosts/nixos/zky/vars.nix nix/hosts/nixos/zly/vars.nix nix/hosts/nixos/zzly/vars.nix
git commit -m "refactor: extract shared host variable defaults"
```

### Task 7: 轻拆 `nix/home/linux/default.nix`

**Files:**
- Optional create: `nix/home/linux/session.nix`
- Optional create: `nix/home/linux/files.nix`
- Modify: `nix/home/linux/default.nix`

- [ ] **Step 1: 保持模块边界最小化**

`session.nix` 只放：
- `waylandSession`
- Linux session variables
- Fcitx activation

`files.nix` 只放：
- repo symlink
- wallpapers
- `.cargo/config.toml`
- `.yarnrc`

- [ ] **Step 2: 不拆 portal/packages/programs**

这些边界当前已经足够清楚，不在本轮调整。

- [ ] **Step 3: 运行验证**

Run: `just eval-tests`
Expected: 全部通过

- [ ] **Step 4: 提交**

```bash
git add nix/home/linux/default.nix nix/home/linux/session.nix nix/home/linux/files.nix
git commit -m "refactor: split linux home entry into session and files modules"
```

## Recommended Order

1. Chunk 1 / Task 1
2. Chunk 1 / Task 2
3. Chunk 2 / Task 4
4. Chunk 2 / Task 5
5. Chunk 2 / Task 3
6. 仅在前面稳定后再评估 Chunk 3

## Stop Conditions

- 如果 `formFactor` 在仓库外部脚本或私有 deploy 流程中被消费，停止删除它，只补文档说明。
- 如果 `roles.desktop` 删除导致太多 role 模块联动，停止在 Chunk 2，维持现状并仅记录约束。
- 如果 shared `vars-common.nix` 让 `stateVersion` 变得不再显式，放弃 Task 6。

## Verification Matrix

- `just hosts`
- `just eval-tests`
- 改了 Nix：`just fmt && just lint`
- 改了 registry/schema/check scripts：`just repo-check`

## Best-Practice Notes

- 保持每台主机仍有自己的目录入口；不要为了 DRY 删除 `hardware.nix` / `hardware-modules.nix` 的职责分离。
- `system.stateVersion` 与 `home.stateVersion` 继续显式留在 host vars，避免隐藏 compatibility boundary。
- system-level `xdg.portal` 与 user-level `xdg.portal` 可共享数据源，但不强求合并为单一 option 定义。
