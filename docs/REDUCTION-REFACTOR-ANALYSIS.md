# 减法重构分析（对标 3 个参考仓库）

更新时间：2026-03-09

参考仓库：
- https://github.com/wimpysworld/nix-config
- https://github.com/Misterio77/nix-config
- https://github.com/ryan4yin/nix-config

---

## 1. 对标结论（可直接复用的设计思想）

### 1.1 wimpysworld/nix-config
- 特征：按 `common` / `nixos` / `darwin` / `home` 做分层，主机定义集中，模块内自带开关判断。
- 可借鉴点：主机层只描述“事实”（hostname、硬件、角色），功能启用逻辑尽量收敛到模块层，避免 host 侧散落条件分支。

### 1.2 Misterio77/nix-config
- 特征：强调 simple、可读、低认知负担，避免 overengineered；不依赖复杂自定义框架。
- 可借鉴点：减少“抽象为了抽象”的 helper；保持“读 1-2 个文件就能理解装配路径”。

### 1.3 ryan4yin/nix-config
- 特征：目录层次清晰，`hosts` / `modules` / `home` / `scripts` 边界明确，并保留 deploy/automation 入口。
- 可借鉴点：把“平台装配逻辑”和“业务模块逻辑”分开，减少跨层耦合。

---

## 2. 当前仓库现状（量化快照）

基于当前仓库统计（`find nix -type f`）：
- `nix` 总文件数：107
- `nix/hosts`：44
- `nix/home`：28
- `nix/modules`：18
- `nix/scripts`：6
- `nix/lib`：9
- `nix/overlays`：1
- `nix/patches`：1

现状判断：
- 优点：
  - 主干清晰：`nix/hosts`、`nix/modules`、`nix/home`、`nix/scripts`
  - 已实现多平台（NixOS + Darwin）与 host 自动发现
  - 已有 eval tests 与 `just` 命令入口
- 主要复杂度：
  - `nix/lib/default.nix` 仍承载较多职责（装配/校验/helper）
  - 两个平台 `outputs` 的共性模板仍可继续收敛
  - `hosts` 与 `outputs` 的边界对新贡献者仍有学习成本

---

## 3. 已完成的减法重构（历史累计）

1. 角色模块去中转，入口直连  
   - 移除 `nix/modules/core/role-services.nix` 与 `nix/modules/core/roles/default.nix`  
   - 在 `nix/modules/core/default.nix` 直接导入 roles

2. 输出层重复模板收敛  
   - `nix/hosts/outputs/x86_64-linux/default.nix`  
   - `nix/hosts/outputs/aarch64-darwin/default.nix`  
   - 统一 eval checks 生成与合并套路

3. lib 层补齐通用小函数并复用  
   - 非空字符串/正整数校验 helper
   - name->attrs、按 key 合并 attrs、specs->attrs
   - 可选 path/import 与 host data entry 组装 helper

---

## 4. 目标结构（减法版，最小迁移成本）

建议目标（非推翻式重构）：

```text
nix/
├── hosts/
│   ├── nixos/<host>/
│   ├── darwin/<host>/
│   └── outputs/
│       ├── default.nix
│       ├── x86_64-linux/default.nix
│       ├── aarch64-darwin/default.nix
│       └── common.nix             # 建议新增：shared builders
├── modules/
│   ├── core/
│   └── darwin/
├── home/
│   ├── base/
│   ├── linux/
│   ├── darwin/
│   └── configs/
├── lib/
│   ├── default.nix                # 导出层（re-export）
│   ├── host-meta.nix              # 建议拆出 schema/roleFlags
│   ├── attrs.nix                  # 建议拆出 merge/map helpers
│   ├── validation.nix             # 建议拆出断言 helper
│   └── launchers.nix              # 建议拆出 launcher helpers
└── scripts/
    └── admin/
```

---

## 5. 迁移路线（推荐分阶段）

### Phase A（已完成）
- 入口去中转
- 输出层模板收敛
- 主机 vars 校验去重

### Phase B（已完成）
- 已新增 `nix/hosts/outputs/common.nix`，把 `mkEvalCheck`、`resolve-host` 模板、apps 组装共性下沉
- 平台文件仅描述差异

### Phase C（已完成）
- 已拆分 `nix/lib/host-meta.nix`（`hostMetaSchema` + `roleFlags`）
- 已拆分 `nix/lib/attrs.nix`（`hasNonEmptyString`、`mergeAttrFromList*`、`discoverHostNamesBy` 等）
- 已拆分 `nix/lib/launchers.nix`（`mkLogFilteredLauncher`）
- 已拆分 `nix/lib/validation.nix`（主机 vars/path 断言 helper）
- `nix/lib/default.nix` 已改为 re-export 以上能力

### Phase D（已完成）
- NixOS host 目录增加薄 `default.nix`（统一 host 入口，集中 import `hardware.nix` + `disko.nix`）
- 输出层测试文件扁平化，移除平台 `tests/` 目录镶套
- 同步 `nix/hosts/README.md` 与 `nix/hosts/outputs/README.md`

---

## 6. 校验策略（每阶段必须执行）

最小校验集合：
- `just eval-tests`
- `just flake-check`
- `just lint`

平台相关（按环境可用性）：
- Linux：`just host=<nixos-host> check`
- Darwin：`just darwin-check`

---

## 7. 风险与回滚

- 风险重点：attr merge 顺序变化、optional import 语义变化、host auto-discovery 过滤逻辑变化。
- 回滚原则：每个 Phase 单独提交，出现回归仅回滚该 Phase。

---

## 8. 执行标准（Done Definition）

- 新贡献者从 `flake.nix -> nix/hosts/outputs/* -> nix/lib/* -> host vars` 的理解路径不超过 10 分钟。
- 同类逻辑只出现一处（例如 eval checks 组装、host data entry 组装）。
- 重构后 `just eval-tests` 与 `just flake-check` 通过。
