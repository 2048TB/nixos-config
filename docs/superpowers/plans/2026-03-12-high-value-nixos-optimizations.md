# High-Value NixOS Optimizations Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将当前仓库从“已具备 host metadata/capability 基础”推进到“metadata 驱动的自发现模块、显示拓扑驱动桌面配置、最小 host 目录、可复用 flake API”的完整形态。

**Architecture:** 先稳定 metadata 和 capability 作为唯一判断源，再把 NixOS/Home Manager 入口切到 auto-discovered self-gating mixins，最后让显示拓扑和 flake exports 消费这层声明。整个实施过程中，避免重新引入旧 `profiles` 风格的双轨模型；host-specific 目录只保留确实属于 hardware 或 install 的内容。

**Tech Stack:** Nix flakes, NixOS modules, Home Manager, TOML registry, shell regression tests, `just`, `nix eval`, `nix flake check`

---

## File Structure

### Existing files to modify

- `nix/hosts/registry/systems.toml`
- `nix/hosts/registry/systems.schema.json`
- `nix/lib/host-registry.nix`
- `nix/lib/host-capabilities.nix`
- `nix/lib/host-meta.nix`
- `nix/lib/default.nix`
- `nix/lib/mkNixosHost.nix`
- `nix/modules/core/default.nix`
- `nix/home/linux/default.nix`
- `nix/home/linux/desktop.nix`
- `nix/home/base/resolve-host.nix`
- `nix/home/configs/niri/appearance.kdl`
- `nix/home/configs/noctalia/settings.json`
- `nix/hosts/outputs/default.nix`
- `nix/hosts/outputs/x86_64-linux/default.nix`
- `nix/pkgs/default.nix`
- `nix/overlays/default.nix`
- `nix/modules/nixos/default.nix`
- `nix/modules/home-manager/default.nix`
- `nix/scripts/tests/test-registry-and-audit.sh`
- `nix/scripts/admin/repo-check.sh`
- `docs/README.md`
- `docs/NIX-COMMANDS.md`
- `nix/hosts/README.md`
- `nix/hosts/nixos/README.md`
- `nix/hosts/outputs/README.md`
- `AGENTS.md`
- `CLAUDE.md`

### New files/directories to create

- `nix/modules/core/_mixins/default.nix`
- `nix/modules/core/_mixins/README.md`
- `nix/home/linux/_mixins/default.nix`
- `nix/home/linux/_mixins/README.md`
- `nix/lib/display-topology.nix`
- `nix/hosts/nixos/_shared/generated-desktop-checks.nix`

### Directory responsibility after refactor

- `nix/hosts/registry/*`: 唯一 host metadata source of truth，包括显示拓扑与更细粒度标签。
- `nix/lib/*`: schema、capability、display topology 纯函数与 builder glue。
- `nix/modules/core/_mixins/*`: NixOS system-level self-gating modules，自发现导入。
- `nix/home/linux/_mixins/*`: Home Manager Linux self-gating modules，自发现导入。
- `nix/hosts/nixos/<host>/*`: 仅保留 hardware / disko / vars / 必要 host-local patch。
- `nix/hosts/outputs/*`: flake outputs 汇总与导出面。

## Chunk 1: Auto-Discovered Self-Gating Mixins

### Task 1: 为 NixOS core 模块建立自发现 mixin 入口

**Files:**
- Create: `nix/modules/core/_mixins/default.nix`
- Create: `nix/modules/core/_mixins/README.md`
- Modify: `nix/modules/core/default.nix`
- Test: `nix/scripts/admin/repo-check.sh`

- [ ] **Step 1: 写出目录扫描规则**

在 `nix/modules/core/_mixins/default.nix` 中定义目录扫描逻辑，只导入当前 `core` 下需要自动纳管的模块文件，并显式排除：

```nix
{ lib, ... }:
let
  here = ./.;
  entries = builtins.readDir here;
  importable =
    builtins.filter
      (name:
        name != "default.nix"
        && name != "README.md"
        && lib.hasSuffix ".nix" name)
      (builtins.attrNames entries);
in
map (name: here + "/${name}") importable
```

- [ ] **Step 2: 运行一次最小 eval，确认 discovery 文件可被解释**

Run: `nix eval --expr 'let lib = import <nixpkgs/lib>; in import ./nix/modules/core/_mixins/default.nix { inherit lib; }'`
Expected: 返回 `.nix` 路径列表；不报语法错误

- [ ] **Step 3: 将 `nix/modules/core/default.nix` 切换为 mixin import**

把现在的硬编码 import list 从：

```nix
imports = [
  ./options.nix
  ./nix-settings.nix
  ./assertions.nix
  ./roles/firewall.nix
  ...
];
```

改成：

```nix
imports =
  [
    ./options.nix
    ./_mixins
  ];
```

同时把当前 `core` 下适合自发现的模块移入 `_mixins/` 或在 `_mixins/default.nix` 中显式拼接 `../roles/*.nix`，但最终要求是以后新增 self-gating 模块不再修改 `default.nix`。

- [ ] **Step 4: 跑仓库级回归**

Run: `bash nix/scripts/admin/repo-check.sh`
Expected: `shell syntax`、`shell regression tests`、`registry check`、`eval tests`、`flake check` 全部通过

- [ ] **Step 5: Commit**

```bash
git add nix/modules/core/default.nix nix/modules/core/_mixins/default.nix nix/modules/core/_mixins/README.md
git commit -m "refactor: auto-discover nixos core mixins"
```

### Task 2: 为 Home Manager Linux 建立自发现 mixin 入口

**Files:**
- Create: `nix/home/linux/_mixins/default.nix`
- Create: `nix/home/linux/_mixins/README.md`
- Modify: `nix/home/linux/default.nix`
- Modify: `nix/home/linux/desktop.nix`
- Test: `nix/scripts/admin/eval-tests.sh`

- [ ] **Step 1: 为 HM Linux 写出与 core 对称的 discovery 层**

在 `nix/home/linux/_mixins/default.nix` 中导入 `desktop.nix`、`files.nix`、`packages.nix`、`programs.nix`、`session.nix`、`xdg.nix` 的新位置，要求结构与 `nix/modules/core/_mixins/default.nix` 保持一致。

- [ ] **Step 2: 将 `nix/home/linux/default.nix` 改成固定入口 + auto-discovery**

入口只保留：

```nix
imports = [
  ../base
  noctalia.homeModules.default
  ./_mixins
];
```

避免后续新增 Linux HM 模块时再次维护手写列表。

- [ ] **Step 3: 检查 desktop 模块 gating**

确认 `nix/home/linux/desktop.nix` 内的图形服务和 launcher 行为仍仅由 `my.host` / `my.capabilities` 决定，不再隐式依赖被 import 的顺序。

- [ ] **Step 4: 运行 eval tests**

Run: `bash nix/scripts/admin/eval-tests.sh .`
Expected: NixOS/Darwin host eval 测试通过；不出现 Home Manager import 缺失

- [ ] **Step 5: Commit**

```bash
git add nix/home/linux/default.nix nix/home/linux/desktop.nix nix/home/linux/_mixins/default.nix nix/home/linux/_mixins/README.md
git commit -m "refactor: auto-discover home-manager linux mixins"
```

## Chunk 2: Registry and Capability as the Only Source of Truth

### Task 3: 扩展 registry schema 到 display topology 和 typed tags

**Files:**
- Modify: `nix/hosts/registry/systems.toml`
- Modify: `nix/hosts/registry/systems.schema.json`
- Modify: `nix/lib/host-registry.nix`
- Modify: `nix/lib/host-meta.nix`
- Test: `nix/scripts/tests/test-registry-and-audit.sh`

- [ ] **Step 1: 在 schema 中新增 display/topology 字段**

为每个 host 增加可选结构：

```json
"desktopProfile": { "type": ["string", "null"] },
"displays": {
  "type": "array",
  "items": {
    "type": "object",
    "required": ["name", "width", "height"],
    "properties": {
      "name": { "type": "string" },
      "width": { "type": "integer" },
      "height": { "type": "integer" },
      "refresh": { "type": ["integer", "null"] },
      "scale": { "type": ["number", "null"] },
      "primary": { "type": "boolean" },
      "workspaceSet": { "type": "array", "items": { "type": "integer" } }
    },
    "additionalProperties": false
  }
}
```

- [ ] **Step 2: 在 registry validator 中加断言**

在 `nix/lib/host-registry.nix` 中为 `desktopProfile`、`displays`、`tags` 建立严格断言，要求：
- `tags` 只能来自 canonical vocabulary
- `displays` 为 list of attrs
- `scale` 为正数
- `workspaceSet` 只能包含正整数

- [ ] **Step 3: 在实际 registry 中先为现有 host 填入最小可用数据**

优先覆盖：
- `nixos.zly`
- `nixos.zky`
- `nixos.zzly`
- `darwin.zly-mac`

至少填入 `desktopProfile` 和空/最小 `displays`，避免 schema 落地后出现双轨。

- [ ] **Step 4: 跑 registry regression**

Run: `bash nix/scripts/tests/test-registry-and-audit.sh`
Expected: schema strictness、host entries、deploy metadata、registry regression 全部通过

- [ ] **Step 5: Commit**

```bash
git add nix/hosts/registry/systems.toml nix/hosts/registry/systems.schema.json nix/lib/host-registry.nix nix/lib/host-meta.nix nix/scripts/tests/test-registry-and-audit.sh
git commit -m "refactor: extend host registry with display topology"
```

### Task 4: 收敛 tags/roles 为统一 gating 接口

**Files:**
- Modify: `nix/lib/host-capabilities.nix`
- Modify: `nix/lib/host-meta.nix`
- Modify: `nix/modules/core/roles/*.nix`
- Modify: `nix/home/base/resolve-host.nix`
- Test: `nix/hosts/nixos/_shared/checks.nix`

- [ ] **Step 1: 在 capability 层加入 tag helpers 与派生布尔值**

把 `tags` 从被动字段提升为可消费能力：

```nix
{
  hasTag = tag: builtins.elem tag tags;
  isStudio = builtins.elem "studio" tags;
  isThinkPad = builtins.elem "thinkpad" tags;
  hasFingerprintReader = builtins.elem "fprintd" tags;
}
```

- [ ] **Step 2: 明确 roles 的职责边界**

在 `nix/lib/host-meta.nix` 中把 `roles` 限定为“功能开关”而非“机器特征”，并把适合成为 metadata 的内容迁到 `tags` 或 `desktopProfile`。要求最终规则清晰：
- `kind / formFactor / desktopProfile / displays / gpuVendors / tags` 描述主机事实
- `roles` 只描述是否启用某功能栈

- [ ] **Step 3: 改造至少一个现有消费点验证方向**

优先把以下消费点之一改到 capability/tag：
- 指纹或 laptop 相关服务
- 某个桌面 app/service 只在特定 machine class 启用
- 某个 role 由 metadata 条件替代

- [ ] **Step 4: 加入 eval checks**

在 `nix/hosts/nixos/_shared/checks.nix` 中新增断言，验证：
- `my.capabilities.hasTag "..."` 与 `my.host.tags` 一致
- `roles` 不再承担 machine topology 语义

- [ ] **Step 5: Commit**

```bash
git add nix/lib/host-capabilities.nix nix/lib/host-meta.nix nix/home/base/resolve-host.nix nix/modules/core/roles nix/hosts/nixos/_shared/checks.nix
git commit -m "refactor: unify metadata and role gating"
```

## Chunk 3: Display Topology-Driven Desktop Configuration

### Task 5: 把 display metadata 接到 Niri/Noctalia 生成路径

**Files:**
- Create: `nix/lib/display-topology.nix`
- Modify: `nix/home/linux/desktop.nix`
- Modify: `nix/home/configs/niri/appearance.kdl`
- Modify: `nix/home/configs/noctalia/settings.json`
- Test: `nix/hosts/nixos/_shared/generated-desktop-checks.nix`

- [ ] **Step 1: 写纯函数把 registry displays 转成 compositor/shell 数据**

在 `nix/lib/display-topology.nix` 中实现两个输出：

```nix
{
  mkNiriOutputs = host: ...;
  mkNoctaliaMonitorWidgets = host: ...;
}
```

要求输入是 `config.my.host`，输出为纯 attrs/list，不直接拼文件 I/O。

- [ ] **Step 2: 先让 Niri 消费生成结果**

将 `nix/home/configs/niri/appearance.kdl` 里的 host-specific output block 抽出成模板或由 `xdg.configFile` 生成，至少覆盖：
- output scale
- refresh/mode
- 主屏标记

删除现有单机硬编码：

```kdl
output "HKC OVERSEAS LIMITED MG27Q 0000000000001" {
  mode "2560x1440@165.000"
  scale 1.25
}
```

- [ ] **Step 3: 再让 Noctalia 监视器配置消费生成结果**

把 `nix/home/configs/noctalia/settings.json` 中硬编码的：

```json
"monitorWidgets": [
  { "name": "eDP-1", ... }
]
```

改成从 `mkNoctaliaMonitorWidgets` 生成或 merge；至少不再写死 `eDP-1`。

- [ ] **Step 4: 加生成结果的回归检查**

在 `nix/hosts/nixos/_shared/generated-desktop-checks.nix` 中新增最小断言：
- 有 desktopSession 的 host 能生成 Niri outputs
- 含 display metadata 的 host 能生成 Noctalia monitorWidgets
- 无 display metadata 的 host 返回空列表而不是失败

- [ ] **Step 5: 验证并提交**

Run:
- `just eval-tests`
- `just flake-check`

Expected: 两个命令都通过；桌面 host 的 HM eval 不因 monitor 配置缺失而失败

```bash
git add nix/lib/display-topology.nix nix/home/linux/desktop.nix nix/home/configs/niri/appearance.kdl nix/home/configs/noctalia/settings.json nix/hosts/nixos/_shared/generated-desktop-checks.nix
git commit -m "feat: generate desktop topology from host metadata"
```

### Task 6: 让 NixOS host 目录真正收缩到 hardware-only

**Files:**
- Modify: `nix/lib/mkNixosHost.nix`
- Modify: `nix/hosts/outputs/x86_64-linux/default.nix`
- Modify: `nix/hosts/README.md`
- Modify: `nix/hosts/nixos/README.md`
- Delete or deprecate: `nix/hosts/nixos/*/default.nix` thin wrappers

- [ ] **Step 1: 让 builder 不再强依赖 host-local `default.nix`**

把 `nix/lib/mkNixosHost.nix` 的 host 入口改成：
- 若存在 `nix/hosts/nixos/<host>/default.nix` 则兼容导入一次
- 新路径默认直接拼 `hardware.nix`、`disko.nix`、必要 shared imports

完成后再删除现有薄壳 host `default.nix`。

- [ ] **Step 2: 更新 host discovery required files**

将 `nix/hosts/outputs/x86_64-linux/default.nix` 与相关 host resolver 的 `requiredFiles` 从：

```nix
[ "default.nix" "hardware.nix" "disko.nix" "vars.nix" ]
```

收敛为：

```nix
[ "hardware.nix" "disko.nix" "vars.nix" ]
```

- [ ] **Step 3: 删除重复薄壳文件**

删除：
- `nix/hosts/nixos/zly/default.nix`
- `nix/hosts/nixos/zky/default.nix`
- `nix/hosts/nixos/zzly/default.nix`

前提是 eval/build 已可在无这些文件时通过。

- [ ] **Step 4: 更新文档与新增主机流程**

把文档统一改成“新增 NixOS host = registry + hardware.nix + disko.nix + vars.nix (+ 可选 home.nix / checks.nix)”，不再要求 `default.nix`。

- [ ] **Step 5: Commit**

```bash
git add nix/lib/mkNixosHost.nix nix/hosts/outputs/x86_64-linux/default.nix nix/hosts/README.md nix/hosts/nixos/README.md
git rm nix/hosts/nixos/zly/default.nix nix/hosts/nixos/zky/default.nix nix/hosts/nixos/zzly/default.nix
git commit -m "refactor: make nixos host directories hardware-only"
```

## Chunk 4: Reusable Flake API and Repository Documentation

### Task 7: 把 flake API 补到真正可复用

**Files:**
- Modify: `nix/hosts/outputs/default.nix`
- Modify: `nix/pkgs/default.nix`
- Modify: `nix/overlays/default.nix`
- Modify: `nix/modules/nixos/default.nix`
- Modify: `nix/modules/home-manager/default.nix`
- Test: `nix/scripts/admin/repo-check.sh`

- [ ] **Step 1: 填充 `nix/pkgs/default.nix`**

将当前空实现：

```nix
_: { }
```

改成真正导出本仓库本地 package 集，即使初始只导出一个最小 attrs 也可以，但不能继续为空壳。

- [ ] **Step 2: 对 overlays 做分层**

参考 `Misterio77/standard`，把当前：

```nix
{
  default = final: _prev: import ../pkgs final;
}
```

拆成至少：
- `additions`
- `modifications`
- `unstable-packages`
- `default`（组合层）

要求对外消费者能按需拿单个 overlay，而不是只能拿全部。

- [ ] **Step 3: 填充 `nixosModules` / `homeManagerModules`**

不能继续是 `{ }` 空导出；至少要导出：
- 主 NixOS module entry
- 可复用 HM Linux entry
- 如有必要，再拆出 desktop-only 子模块

- [ ] **Step 4: 跑 flake show/check**

Run:
- `nix flake show`
- `bash nix/scripts/admin/repo-check.sh`

Expected:
- `packages`、`overlays`、`nixosModules`、`homeManagerModules` 可见
- 仓库级检查全部通过

- [ ] **Step 5: Commit**

```bash
git add nix/hosts/outputs/default.nix nix/pkgs/default.nix nix/overlays/default.nix nix/modules/nixos/default.nix nix/modules/home-manager/default.nix
git commit -m "feat: export reusable flake api"
```

### Task 8: 全量同步文档与操作约束

**Files:**
- Modify: `README.md`
- Modify: `docs/README.md`
- Modify: `docs/NIX-COMMANDS.md`
- Modify: `nix/hosts/README.md`
- Modify: `nix/hosts/nixos/README.md`
- Modify: `nix/hosts/outputs/README.md`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: 统一仓库入口文档**

README 与 docs 应说明：
- host metadata 现在包含 display topology
- NixOS/HM 入口改成 auto-discovered mixins
- host 目录默认 hardware-only
- flake exports 可以被外部仓库复用

- [ ] **Step 2: 同步操作命令文档**

在 `docs/NIX-COMMANDS.md` 里补：
- 如何查看导出的 overlays/modules/packages
- 如何验证 registry/display metadata
- 新增主机时不再创建 `default.nix`

- [ ] **Step 3: 同步 agent 约束**

`AGENTS.md` 与 `CLAUDE.md` 中新增或更新：
- 不要重新引入手写 import list
- 不要把 machine topology 信息塞回 `roles`
- 不要在桌面配置中硬编码 monitor 名称

- [ ] **Step 4: 最终验证**

Run:
- `just fmt`
- `just eval-tests`
- `just flake-check`
- `bash nix/scripts/admin/repo-check.sh --full`

Expected: 全部通过；若某台 host build 因外部硬件或 secrets 环境受限失败，必须在文档中明确记录 UNVERIFIED 范围

- [ ] **Step 5: Commit**

```bash
git add README.md docs/README.md docs/NIX-COMMANDS.md nix/hosts/README.md nix/hosts/nixos/README.md nix/hosts/outputs/README.md AGENTS.md CLAUDE.md
git commit -m "docs: align docs with metadata-driven architecture"
```

## Risks and Rollback

- 目录自发现若写得过宽，容易把非 module `.nix` 文件误导入；必须用白名单目录或严格过滤，而不是无脑 `readDir` 全吃。
- display topology 一旦进入 registry，schema 和文档必须同步，不然新增主机会卡在 eval 层。
- 删除 host-local `default.nix` 前，必须先让 builder/discovery 通过；删除顺序不能反。
- `packages` / `overlays` / `modules` 导出面一旦对外可见，后续就会形成 API 约束；命名和边界要在本轮定稳。
- 若某个 chunk 回归失败，按 chunk 粒度回滚最近一次提交，不要跨 chunk 混合修复。

## Recommended Execution Order

1. Chunk 1: 先去掉手写 import list，建立可扩展入口
2. Chunk 2: 再扩展 registry/capabilities，避免后面桌面生成层反复改 schema
3. Chunk 3: 基于 display metadata 改桌面生成，并收缩 host 目录
4. Chunk 4: 最后补 flake API 与文档，避免对外接口在中途反复变化

Plan complete and saved to `docs/superpowers/plans/2026-03-12-high-value-nixos-optimizations.md`. Ready to execute?
