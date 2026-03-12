# NixOS Quality Refinement Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 host metadata/capability 重构后的高价值收尾，消除 display generation、tags 语义、registry 断言与 `_mixins` 导入边界上的剩余质量缺口。

**Architecture:** 继续把 `nix/hosts/registry/systems.toml` 作为唯一 source of truth。桌面拓扑统一从 `displays` 生成，machine facts 从 registry 派生为 capability，`roles` 仅保留功能开关。所有入口继续保持 self-gating，但收紧 `_mixins` 的发现范围，避免隐式导入 drift。

**Tech Stack:** Nix flakes, NixOS modules, Home Manager, TOML registry, shell-based eval/build checks

---

## File Map

- Modify: `nix/lib/display-topology.nix`
  负责把 `host.displays` 变成 `Niri` / `Noctalia` 可消费的数据；当前只覆盖 primary-display 场景。
- Modify: `nix/home/linux/xdg.nix`
  负责把 display topology 接到 `xdg.configFile` 生成链。
- Modify: `nix/home/configs/noctalia/settings.json`
  当前仍保留 `"name": "eDP-1"` 的 monitorWidgets 模板，需要改成与具体显示器无关的 base template。
- Modify: `nix/hosts/registry/systems.toml`
  作为 host metadata 唯一事实源；需要让 tags 与 displays 语义一致。
- Modify: `nix/lib/host-capabilities.nix`
  负责把 registry facts 派生为只读 capability；应避免让 tags 和 capabilities 双轨表达同一事实。
- Modify: `nix/lib/host-registry.nix`
  负责 registry 断言；需要补更强的一致性校验。
- Modify: `nix/modules/core/options.nix`
  保持 typed options 与 capability 暴露面和新的断言/派生规则一致。
- Modify: `nix/modules/core/_mixins/default.nix`
  收紧 NixOS `_mixins` 自动发现范围，避免未来误导入 helper/partial file。
- Modify: `nix/home/linux/_mixins/default.nix`
  收紧 Linux Home Manager `_mixins` 自动发现范围，行为与 core 侧保持一致。
- Modify: `nix/home/linux/session.nix`
  明确 Linux `desktopProfile` 的支持边界，避免抽象名义存在、实现却只有单一路径。
- Modify: `nix/hosts/nixos/_shared/generated-desktop-checks.nix`
  为新的 multi-display 生成逻辑补 eval checks。
- Modify: `nix/hosts/nixos/_shared/checks.nix`
  为 tags/capabilities/desktopProfile 关系补一致性校验。
- Modify: `nix/scripts/tests/test-registry-and-audit.sh`
  为 registry 新约束补回归测试。
- Modify: `README.md`
- Modify: `docs/README.md`
- Modify: `nix/hosts/README.md`
- Modify: `nix/hosts/nixos/README.md`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`
  同步更新规则与维护文档，避免后续重新引入已淘汰的模式。

## Chunk 1: Finish Display Topology Consumers

### Task 1: 让 Noctalia 真正消费完整 `displays`

**Files:**
- Modify: `nix/lib/display-topology.nix`
- Modify: `nix/home/linux/xdg.nix`
- Modify: `nix/hosts/nixos/_shared/generated-desktop-checks.nix`

- [ ] **Step 1: 先写失败预期，定义 multi-display 输出规则**

目标规则：
- `mkNoctaliaMonitorWidgets` 对 `host.displays` 中每个 display 都生成一项
- `widgetsTemplate` 只作为 widget 内容模板，不再绑定任何 monitor name
- 如果 `displays = []`，则生成 `[]`

- [ ] **Step 2: 为生成逻辑补 eval checks**

在 `nix/hosts/nixos/_shared/generated-desktop-checks.nix` 增加：
- 对多显示器 host，检查生成的 `monitorWidgets` 长度等于 `builtins.length hostCfg.displays`
- 对 primary display，检查 `cfg.my.capabilities.primaryDisplayName` 与 `mylib.primaryDisplay hostCfg` 一致

Run: `just eval-tests`
Expected: 先 FAIL，暴露当前 single-monitor only 行为

- [ ] **Step 3: 最小实现 multi-display Noctalia generation**

在 `nix/lib/display-topology.nix` 中把：

```nix
mkNoctaliaMonitorWidgets = { host, widgetsTemplate ? [ ] }: ...
```

改成对全部 displays `map`，每个 display 生成：

```nix
{
  name = display.name;
  widgets = widgetsTemplate;
}
```

同时保留 `displays = [] -> []`。

- [ ] **Step 4: 接回 Home Manager 生成链**

在 `nix/home/linux/xdg.nix` 中保持：
- 只读取 base widgets template
- 不再假设只有一个 monitorWidgets entry
- 生成的 `noctalia/settings.json` 完全由 `mkNoctaliaMonitorWidgets` 决定 monitor list

- [ ] **Step 5: 运行校验**

Run: `just eval-tests`
Expected: PASS

Run: `just flake-check`
Expected: PASS

### Task 2: 清掉 Noctalia base template 里的 monitor name 残留

**Files:**
- Modify: `nix/home/configs/noctalia/settings.json`
- Modify: `nix/home/linux/xdg.nix`
- Modify: `README.md`
- Modify: `docs/README.md`

- [ ] **Step 1: 把 base JSON 改成 monitor-agnostic template**

将 `nix/home/configs/noctalia/settings.json` 中：

```json
"monitorWidgets": [
  { "name": "eDP-1", "widgets": [...] }
]
```

改成不携带真实 monitor name 的模板结构。优先方案：
- 保留 `monitorWidgets` 数组但把 `name` 改为 `"__TEMPLATE__"`，并在生成阶段完全丢弃该值
- 如果 Noctalia 允许，也可以直接提取为单独 template section

- [ ] **Step 2: 让生成端显式忽略模板 monitor name**

在 `nix/home/linux/xdg.nix` 中：
- 只取模板里的 `widgets`
- 不把模板 `name` 透传到最终结果

- [ ] **Step 3: 运行针对性检查**

Run: `nix eval --json .#checks.x86_64-linux.eval-zly-generated-noctalia-settings`
Expected: derivation evaluates successfully

Run: `just eval-tests`
Expected: PASS

---

## Chunk 2: Remove Machine-Fact Drift Between Tags and Capabilities

### Task 3: 收掉与 `displays` 重复表达的 tags

**Files:**
- Modify: `nix/hosts/registry/systems.toml`
- Modify: `nix/lib/host-capabilities.nix`
- Modify: `nix/hosts/nixos/_shared/checks.nix`
- Modify: `nix/hosts/README.md`
- Modify: `nix/hosts/nixos/README.md`

- [ ] **Step 1: 明确 tag 分类边界**

规则定为：
- `tags` 只保留当前无法稳定从其他 metadata 派生的事实
- `multi-monitor`、`hidpi` 这类能从 `displays` 推导的 tag 不再手写

- [ ] **Step 2: 先写失败检查**

在 `nix/hosts/nixos/_shared/checks.nix` 增加：
- `cfg.my.capabilities.hasMultipleDisplays == (builtins.length cfg.my.host.displays > 1)`
- `cfg.my.capabilities.hasHiDpiDisplay == any (scale > 1.0) displays`

同时增加“不再依赖 `multi-monitor` / `hidpi` tag 驱动 capability”的断言说明。

- [ ] **Step 3: 调整真实 registry 数据**

在 `nix/hosts/registry/systems.toml` 中：
- 删除可由 `displays` 推导的 `tags`
- 如果某主机确实是多显示器，补全第二个 display，而不是继续使用 `multi-monitor` tag 占位

- [ ] **Step 4: 最小实现 capability 侧收口**

在 `nix/lib/host-capabilities.nix` 中保持：
- `hasMultipleDisplays` 只来自 `displays`
- `hasHiDpiDisplay` 只来自 `displays.scale`
- `hasFingerprintReader` 这类仍无法推导的能力，才继续来自 `tags`

- [ ] **Step 5: 运行回归**

Run: `bash nix/scripts/tests/test-registry-and-audit.sh`
Expected: PASS

Run: `just eval-tests`
Expected: PASS

### Task 4: 强化 registry 一致性断言

**Files:**
- Modify: `nix/lib/host-registry.nix`
- Modify: `nix/scripts/tests/test-registry-and-audit.sh`
- Modify: `nix/hosts/registry/systems.schema.json`

- [ ] **Step 1: 写出必须满足的约束**

新增断言：
- `desktopSession = false` 时，`desktopProfile` 必须是 `"none"`
- `desktopSession = true` 时，`desktopProfile` 不能是 `"none"`
- `displays` 中 `primary = true` 最多一个
- `primary = true` 的 display 如果存在，`name` 不能为空
- `multi-monitor` / `hidpi` 若仍保留在 schema 中，必须只作为过渡保留并禁止在真实 hosts 中继续使用

- [ ] **Step 2: 在 shell 测试里加入坏例子**

在 `nix/scripts/tests/test-registry-and-audit.sh` 里增加临时 fixture：
- `desktopSession = false` + `desktopProfile = "niri"` 应 FAIL
- 两个 `primary = true` 的 display 应 FAIL

- [ ] **Step 3: 实现断言**

在 `nix/lib/host-registry.nix` 中用 `lib.assertMsg` 增加上述约束。

- [ ] **Step 4: 运行校验**

Run: `bash nix/scripts/tests/test-registry-and-audit.sh`
Expected: PASS

Run: `just repo-check`
Expected: PASS

---

## Chunk 3: Harden Module Discovery and Desktop Profile Boundaries

### Task 5: 收紧 `_mixins` 自动发现范围

**Files:**
- Modify: `nix/modules/core/_mixins/default.nix`
- Modify: `nix/home/linux/_mixins/default.nix`
- Modify: `nix/modules/core/_mixins/README.md`
- Modify: `nix/home/linux/_mixins/README.md`

- [ ] **Step 1: 定义导入边界**

将自动发现规则改成二选一：
- 只扫描 `_mixins/` 目录下的 regular `.nix` 文件
- 对 `roles/` 继续单独显式拼接

不要再扫描 parent 目录的全部 `.nix` 文件。

- [ ] **Step 2: 如有需要，迁移现有 mixin 文件**

如果当前 `desktop.nix`、`packages.nix`、`programs.nix` 等仍留在 `nix/home/linux/` 根目录，则把真正需要 auto-import 的文件迁到 `_mixins/`，或者在 `_mixins/default.nix` 中显式列出允许文件名。

- [ ] **Step 3: 验证新发现逻辑**

Run: `nix eval --expr 'let lib = import <nixpkgs/lib>; in import ./nix/modules/core/_mixins/default.nix { inherit lib; }'`
Expected: 只返回预期 mixin file 列表

Run: `nix eval --expr 'let lib = import <nixpkgs/lib>; in import ./nix/home/linux/_mixins/default.nix { inherit lib; }'`
Expected: 只返回预期 HM mixin file 列表

- [ ] **Step 4: 运行全量回归**

Run: `just eval-tests`
Expected: PASS

Run: `just flake-check`
Expected: PASS

### Task 6: 明确 Linux `desktopProfile` 的实际支持边界

**Files:**
- Modify: `nix/home/linux/session.nix`
- Modify: `nix/lib/host-meta.nix`
- Modify: `nix/hosts/README.md`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: 做出明确决策**

二选一，只选其一，不保留模糊状态：
- 如果近期只支持 `niri`，就在文档和断言里明确 Linux 侧 `desktopProfile` 当前仅允许 `niri`
- 如果准备支持第二个 Linux desktop profile，就补完整执行链，不要只停在 schema

当前建议：先明确 `Linux == niri-only`，Darwin 使用 `aqua`。

- [ ] **Step 2: 落地最小实现**

如果采用 `niri-only`：
- 保持 `session.nix` 的 `throw`
- 在 schema/docs/checks 中明确这是设计约束，不是临时 TODO

如果采用扩展支持：
- 为新增 profile 补 session exec / env / checks

- [ ] **Step 3: 运行校验**

Run: `just eval-tests`
Expected: PASS

Run: `just repo-check`
Expected: PASS

---

## Chunk 4: Docs and Final Regression Sweep

### Task 7: 同步所有维护文档

**Files:**
- Modify: `README.md`
- Modify: `docs/README.md`
- Modify: `nix/hosts/README.md`
- Modify: `nix/hosts/nixos/README.md`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: 更新 display topology 规则**

文档中明确：
- `displays` 是桌面显示布局唯一事实源
- 不要在 `Niri` / `Noctalia` 配置里硬编码 monitor name
- `Noctalia` 的 widget 布局模板不绑定具体 monitor

- [ ] **Step 2: 更新 tags/roles 规则**

文档中明确：
- `roles` 只控制 feature toggle
- `tags` 只保留不可由其他 metadata 派生的事实
- `multi-monitor` / `hidpi` 这类 machine facts 不应继续手写

- [ ] **Step 3: 更新 `_mixins` 规则**

文档中明确：
- 只有 `_mixins/` 目录中的 self-gating 模块会被自动导入
- helper file 不应放在自动扫描目录

### Task 8: 最终验证与提交准备

**Files:**
- Modify: `nix/scripts/tests/test-registry-and-audit.sh`
- Modify: `nix/hosts/nixos/_shared/checks.nix`
- Modify: `nix/hosts/nixos/_shared/generated-desktop-checks.nix`

- [ ] **Step 1: 运行格式与静态检查**

Run: `just fmt`
Expected: PASS

Run: `just lint`
Expected: PASS

- [ ] **Step 2: 运行功能性检查**

Run: `just eval-tests`
Expected: PASS

Run: `just flake-check`
Expected: PASS

Run: `bash nix/scripts/admin/repo-check.sh --full`
Expected: PASS

- [ ] **Step 3: 记录 warning 与未解决项**

若仍存在：
- `warning: unknown flake output 'homeManagerModules'`

则在收尾说明中明确：
- 这是 Nix 对非标准 flake output 名称的 warning
- 如果决定处理，应另开独立任务；不要混入本次质量收尾

