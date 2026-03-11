# NixOS Repository Optimization v2 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改动 flake 输出骨架和 host 分层的前提下，分 6 个可独立合并的 PR 收敛仓库入口、CI、安全防护、registry 约束、flake inputs 与文档入口。

**Architecture:** 保留当前 `flake.nix -> nix/hosts/outputs`、`nix/modules/core + nix/modules/darwin`、`nix/home/*` 的结构，只做“薄入口 + 逻辑下沉 + 校验前移”。目录调整以增量方式进行，优先新增脚本与检查，再收缩 `justfile` 和 CI；避免一次性移动大量 Nix 模块路径。

**Tech Stack:** Nix flakes, NixOS, nix-darwin, Home Manager, Just, Bash, GitHub Actions

---

## 基线结论

- `justfile` 同时承载系统切换、安装、部署、flake 操作、质量检查、Git workflow，已经是第二控制层；其中 `switch`/`boot`/`test`/`check`/`darwin-*` 仍含内联 shell 逻辑，`commit`/`push` 直接使用 `git add .`。证据：`justfile:19`、`justfile:31`、`justfile:68`、`justfile:280`、`justfile:287`
- CI 的 Nix 安装与 host inventory 逻辑重复，轻量 CI 只有 eval，不含任一真实 Linux build。证据：`.github/workflows/ci-light.yml:24`、`.github/workflows/ci.yml:20`、`.github/workflows/ci.yml:61`
- host registry 已经存在，不应重做一套；真实问题是 schema 偏宽松、CI 未单独执行 registry check、deploy 字段不完整。证据：`nix/hosts/registry/systems.toml:1`、`nix/hosts/registry/systems.schema.json:20`、`nix/lib/mkNixosHost.nix:30`
- 安装脚本目前会直接跑 disko 和 `nixos-install`，缺少显式二次确认与磁盘白名单/格式校验。证据：`nix/scripts/admin/install-live.sh:91`、`nix/scripts/admin/install-live.sh:96`、`nix/scripts/admin/install-live.sh:118`
- 文档入口并非完全缺失，但分散在 `docs/README.md`、`nix/hosts/README.md`、`nix/home/README.md`，仓库根缺少统一人类入口。证据：`docs/README.md:1`、`nix/hosts/README.md:1`
- flake inputs 不能先按“看起来多”删除；当前静态扫描显示绝大多数 input 都有代码引用，审计应先做“用途与宿主”表，再决定删除。证据：`flake.nix:7`、`nix/lib/mkNixosHost.nix:13`、`nix/lib/mkDarwinHost.nix:22`

## 目标目录

以最小改动为原则，目标是“新增聚合点，不大规模挪动 Nix 模块路径”：

```text
.
├── flake.nix
├── flake.lock
├── justfile
├── README.md
├── docs/
│   ├── architecture.md
│   ├── ci.md
│   ├── operations.md
│   ├── flake-input-audit.md
│   └── README.md
├── .github/
│   ├── actions/
│   │   └── setup-nix/action.yml
│   └── workflows/
│       ├── ci-light.yml
│       ├── ci-heavy.yml
│       ├── flake-lock-checker.yml
│       └── cleanup-workflow-runs.yml
└── nix/
    ├── hosts/
    │   ├── registry/
    │   │   ├── systems.toml
    │   │   └── systems.schema.json
    │   ├── nixos/
    │   ├── darwin/
    │   └── outputs/
    ├── modules/
    │   ├── core/
    │   └── darwin/
    ├── home/
    │   ├── base/
    │   ├── linux/
    │   ├── darwin/
    │   └── configs/
    └── scripts/
        ├── admin/
        │   ├── resolve-host.sh
        │   ├── rebuild-auto.sh
        │   ├── rebuild-nixos.sh
        │   ├── rebuild-darwin.sh
        │   ├── deploy-hosts.sh
        │   └── install-live.sh
        ├── checks/
        │   ├── repo-check.sh
        │   ├── registry-check.sh
        │   └── unused-inputs.sh
        ├── lib/
        │   ├── common.sh
        │   └── ui.sh
        └── tests/
```

说明：

- 不建议把现有 `nix/modules/core` 拆成 `common/nixos/darwin/home`，因为这会制造大规模 import churn，收益低于风险。
- `systems.schema.json` 保留；不建议改成 `schema.nix` 作为唯一事实源。更稳妥的做法是“JSON schema 负责编辑器/静态描述，Nix assertions + shell check 负责 CI 真门禁”。
- CI 复用建议优先采用 composite action，而不是单独的 `reusable-nix-setup.yml`。当前重复主要发生在 step 级别，composite action 更贴近现状，迁移成本更低。

## PR 顺序

执行顺序固定：

1. PR-1 安全优化
2. PR-2 `justfile` 瘦身
3. PR-3 CI 重构
4. PR-4 flake inputs 审计
5. PR-5 registry 标准化
6. PR-6 文档整理

依赖关系：

- PR-2 依赖 PR-1 的危险操作保护模式，避免在拆脚本时重复改一遍。
- PR-3 依赖 PR-2 的脚本边界，才能让本地检查与 CI 共享同一套入口。
- PR-5 放在 PR-4 后，避免 registry 字段调整与 inputs/CI 变动交织。

## Chunk 1: PR-1 安全优化

### Task 1: 收紧 Git 提交流程

**Files:**
- Modify: `justfile:280`
- Modify: `justfile:287`
- Test: `nix/scripts/tests/test-safety.sh`

- [ ] **Step 1: 将 `git add .` 替换为显式 stage 策略**

将 `commit` / `push` recipe 从：

```bash
git add .
```

替换为：

```bash
git add -A :/
git diff --cached --stat
```

- [ ] **Step 2: 在 commit 前保留 `guard-secrets`**

保持 `just guard-secrets` 在 `git commit` 前执行，不与 stage 命令合并，确保失败时不会继续 commit。

- [ ] **Step 3: 补一个 shell 回归测试或文档化 smoke check**

如果现有测试框架不方便直接断言 `just` recipe，可至少在 `repo-check.sh` 的 shell 语法检查之外新增“grep 防回归”检查：

```bash
rg -n "git add \\\\." justfile && exit 1 || true
```

- [ ] **Step 4: 手工验证 stage 输出**

Run: `just commit "test: stage guard"`  
Expected: 先显示 `git diff --cached --stat`，再执行 `guard-secrets`，最后提交。

- [ ] **Step 5: Commit**

```bash
git add justfile nix/scripts/tests
git commit -m "fix: harden git staging workflow"
```

### Task 2: 为安装与高风险清理增加确认

**Files:**
- Modify: `nix/scripts/admin/install-live.sh:1`
- Modify: `nix/scripts/admin/common.sh:1` 或新增 `nix/scripts/lib/ui.sh`
- Modify: `justfile:87`
- Modify: `justfile:100`
- Test: `nix/scripts/tests/test-safety.sh`

- [ ] **Step 1: 抽一个统一确认函数**

新增 `confirm_destructive_action`，要求操作者输入精确 token，例如：

```bash
confirm_destructive_action "INSTALL ${host} ${disk}"
```

- [ ] **Step 2: 在 `install-live.sh` 进入 disko 前强制确认**

确认信息必须包含 host、disk、repo，并明确说明“将清空目标磁盘”。

- [ ] **Step 3: 增加磁盘参数校验**

至少校验：

```bash
[[ "$disk" == /dev/* ]]
[ -b "$disk" ]
```

如果要支持 `/dev/disk/by-id/*`，同步放宽模式，但必须仍要求块设备存在。

- [ ] **Step 4: 为 `just clean-all` 加确认**

`clean-all` 也是不可逆操作，应复用同一确认函数，而不是继续裸跑 `nix-collect-garbage -d`。

- [ ] **Step 5: 验证**

Run: `bash nix/scripts/admin/install-live.sh --host zly --disk /dev/does-not-exist`  
Expected: 参数校验失败，不触发 disko

Run: `just clean-all`  
Expected: 未确认前不执行删除

### PR-1 验收标准

- `justfile` 不再出现 `git add .`
- 所有危险命令在真正执行前都有二次确认
- 无效磁盘路径在 disko 前失败
- 现有安装/仓库检查脚本仍能通过 shell 语法检查

### PR-1 风险与回滚

- 风险：自动化环境调用 `install-live.sh` 可能被新确认提示阻塞
- 控制：仅在交互式 TTY 下默认要求确认；非交互式场景通过明确 `--yes` 打开
- 回滚：单独回退 `install-live.sh` 与 `justfile` recipe，不影响 flake 输出

## Chunk 2: PR-2 `justfile` 瘦身

### Task 3: 把 rebuild 逻辑从 recipe 下沉到脚本

**Files:**
- Create: `nix/scripts/admin/rebuild-auto.sh`
- Create: `nix/scripts/admin/rebuild-nixos.sh`
- Create: `nix/scripts/admin/rebuild-darwin.sh`
- Modify: `justfile:19`
- Modify: `justfile:68`
- Modify: `nix/scripts/admin/common.sh` 或 `nix/scripts/lib/common.sh`

- [ ] **Step 1: 固化 NixOS rebuild 参数解析**

将当前 `switch` / `boot` / `test` / `check` 的 host 自动解析、preflight、`nom` 管道逻辑迁移到脚本。

- [ ] **Step 2: 固化 Darwin rebuild 参数解析**

将 `darwin-switch` / `darwin-check` 的 host 自动解析与 preflight 迁移到脚本。

- [ ] **Step 3: 让 `justfile` 只保留薄入口**

目标是 recipe 形态接近：

```bash
switch:
    @nix/scripts/admin/rebuild-auto.sh nixos switch "{{host}}" "{{repo}}"
```

- [ ] **Step 4: 收敛共享 shell helper**

把通用 helper 从 `nix/scripts/admin/common.sh` 挪到 `nix/scripts/lib/common.sh`；如需最小 diff，可先保留 `admin/common.sh` 作为兼容 wrapper。

- [ ] **Step 5: 验证**

Run: `just host=zly check`  
Expected: 成功构建 `.#nixosConfigurations.zly.config.system.build.toplevel`

Run: `just darwin_host=zly-mac darwin-check`  
Expected: 成功构建或 eval Darwin system

### Task 4: 收缩 `justfile` 职责边界

**Files:**
- Modify: `justfile`
- Modify: `docs/README.md:1`

- [ ] **Step 1: 将“复杂业务逻辑”迁移出 `justfile`**

保留 `just` 的职责为：

- 命令别名与入口
- 默认参数
- 帮助说明

避免继续把条件分支、host fallback、循环和长管道留在 recipe 中。

- [ ] **Step 2: 为未来扩展预留统一入口命名**

建议按三类命名：

- `admin/` 执行动作
- `checks/` 校验动作
- `tests/` 脚本回归

- [ ] **Step 3: 验证**

Run: `just --list`  
Expected: 所有原有高频命令名仍保留，不需要用户迁移用法

### PR-2 验收标准

- `justfile` 不再内嵌核心业务逻辑
- 所有系统切换/检查命令都能通过脚本单独调用
- 现有命令名与参数基本兼容

### PR-2 风险与回滚

- 风险：脚本迁移后参数顺序不兼容，导致本地 muscle memory 失效
- 控制：先兼容旧命令名与旧默认参数，再在文档中声明未来弃用项
- 回滚：保留原 `justfile` recipe 可快速恢复，不影响 host 配置

## Chunk 3: PR-3 CI 重构

### Task 5: 抽取共享 Nix setup

**Files:**
- Create: `.github/actions/setup-nix/action.yml`
- Modify: `.github/workflows/ci-light.yml`
- Move/Modify: `.github/workflows/ci.yml` -> `.github/workflows/ci-heavy.yml`

- [ ] **Step 1: 建立 composite action 复用 checkout 之后的 Nix 安装**

action 至少包含：

- 安装 Nix
- 打开 `nix-command flakes`
- 可选公共缓存/`extra-conf`

- [ ] **Step 2: 统一 workflow 名称**

将 `ci.yml` 更名为 `ci-heavy.yml`，与现有 `ci-light.yml` 对齐，减少“文件名和 workflow name 不一致”的维护成本。

- [ ] **Step 3: 让 inventory 逻辑尽量复用仓库脚本**

可新增 `nix/scripts/checks/list-hosts.sh` 或直接复用现有 `nix eval` 片段；避免同一段 inventory shell 同时存在于 CI 和本地脚本。

### Task 6: 提高 Light CI 的真实性

**Files:**
- Modify: `.github/workflows/ci-light.yml`
- Create: `nix/scripts/checks/registry-check.sh`
- Modify: `nix/scripts/admin/repo-check.sh`

- [ ] **Step 1: 为 Light CI 增加 registry check**

优先跑：

```bash
bash nix/scripts/checks/registry-check.sh
```

检查项至少包含：

- TOML 可解析
- 目录与 registry 双向一致
- schema/断言不过宽

- [ ] **Step 2: 为 Light CI 增加 1 台代表性 Linux host build**

推荐固定构建 `zly`，不要用“第一台 host”动态选择，否则门禁样本会漂移。

- [ ] **Step 3: 保留 Darwin eval，但不强求 Linux runner 构建 Darwin**

当前 Linux runner 上做 Darwin drvPath eval 是合理的；不建议把它升级成 build 作为 light gate。

- [ ] **Step 4: Heavy CI 跑全量检查**

Heavy CI 应执行：

- `just repo-check`
- `just repo-check --full` 或等价全 host build matrix

- [ ] **Step 5: 验证**

修改一个 Nix 文件后发起 PR  
Expected: Light CI 至少执行 lint/eval/registry/1 host build

### PR-3 验收标准

- CI 中不再重复粘贴同一段 Nix setup
- Light CI 至少包含 1 个真实 Linux build
- Heavy CI 仍可手动跑全量 host build

### PR-3 风险与回滚

- 风险：Light CI 时间上升
- 控制：light 只 build `zly`，其他 host 留给 heavy
- 回滚：如耗时过大，可暂时保留 registry + eval + 单 host build 三件套，先不加更多检查

## Chunk 4: PR-4 flake inputs 审计

### Task 7: 生成 inputs 审计表并补脚本

**Files:**
- Create: `docs/flake-input-audit.md`
- Create: `nix/scripts/checks/unused-inputs.sh`
- Modify: `flake.nix`

- [ ] **Step 1: 为每个 input 建立事实表**

表头固定：

```text
| input | category | used by | keep | note |
```

`used by` 必须写明宿主文件或 host 范围，例如：

- `nix-homebrew`: `nix/lib/mkDarwinHost.nix`
- `noctalia`: `nix/home/linux/default.nix`, `nix/home/linux/desktop.nix`
- `pre-commit-hooks`: `nix/hosts/outputs/x86_64-linux/default.nix`

- [ ] **Step 2: 把审计脚本做成“提示型”，不是自动删依赖**

脚本只输出：

- 在 `flake.nix` 定义但仓库未静态引用的 input
- 动态引用/条件引用的潜在误判列表

不要让脚本直接改 `flake.nix`。

- [ ] **Step 3: 仅删除证据充分的未使用 inputs**

当前优先怀疑对象应来自审计结果，而不是先验猜测。若某 input 仅在单 host/单模块使用，也不应因为“看起来少用”而删掉。

- [ ] **Step 4: 验证**

Run: `bash nix/scripts/checks/unused-inputs.sh`  
Expected: 输出所有 inputs 的静态引用状况

Run: `just flake-check`  
Expected: 删除候选 input 后仍通过 flake checks

### PR-4 验收标准

- 每个 input 都有“用途-保留-证据”记录
- 任何删除都有对应代码引用消失的证据
- `flake.lock` 体积变化可解释

### PR-4 风险与回滚

- 风险：动态引用导致误删
- 控制：删除前必须 `rg` + `flake check` + 至少 1 host build
- 回滚：单独恢复 `flake.nix` 与 `flake.lock`

## Chunk 5: PR-5 registry 标准化

### Task 8: 收紧 registry schema 与 Nix 断言

**Files:**
- Modify: `nix/hosts/registry/systems.toml`
- Modify: `nix/hosts/registry/systems.schema.json`
- Modify: `nix/lib/mkNixosHost.nix`
- Modify: `nix/lib/mkDarwinHost.nix`
- Modify: `nix/hosts/outputs/common.nix`
- Modify: `nix/scripts/admin/deploy-hosts.sh`

- [ ] **Step 1: 明确 registry 目标字段**

建议字段：

```toml
system = "x86_64-linux"
formFactor = "desktop"
profiles = ["desktop"]
deployEnabled = true
deployHost = "example.internal"
deployUser = "root"
deployPort = 22
```

- [ ] **Step 2: 将 schema 从“描述性”提升到“限制性”**

当前 `systems.schema.json` 的 `entry.additionalProperties = true` 过宽，应改为 `false`，避免 registry silently 接受拼错字段。

- [ ] **Step 3: 在 Nix 侧补 deploy 语义断言**

规则建议：

- `deployEnabled = false` 时可省略 `deployHost` / `deployUser` / `deployPort`
- `deployEnabled = true` 时 `deployHost` 必填
- `deployPort` 默认 22，但若提供必须为正整数

- [ ] **Step 4: 让 deploy 脚本尊重 registry 语义**

`deploy-hosts.sh` 应跳过 `deployEnabled = false` 的主机；若配置了 `deployPort`，应传给 SSH/NixOS deploy path。

- [ ] **Step 5: 验证**

Run: `bash nix/scripts/checks/registry-check.sh`  
Expected: 错误字段、缺字段、目录不一致都会失败

Run: `just deploy HOSTS=zly`  
Expected: 读取 registry 的 deploy 目标与端口

### PR-5 验收标准

- registry 不能再接受未知字段
- deploy 相关字段语义清晰且被脚本消费
- `vars.nix` 继续禁止覆写 registry-owned keys

### PR-5 风险与回滚

- 风险：现有主机条目不满足新 schema，导致一次性 fail
- 控制：先在同一 PR 内完成全量 registry 数据迁移，再启用严格断言
- 回滚：回退 schema 与 deploy 脚本即可，host 目录结构不受影响

## Chunk 6: PR-6 文档整理

### Task 9: 建立单一文档入口

**Files:**
- Create: `README.md`
- Create: `docs/architecture.md`
- Create: `docs/operations.md`
- Create: `docs/ci.md`
- Modify: `docs/README.md`

- [ ] **Step 1: 新增根 `README.md`**

根 README 只做三件事：

- 仓库是什么
- 常用命令入口
- 指向 `docs/` 与 `nix/hosts/README.md`

- [ ] **Step 2: 合并/重定向已有文档**

保留已有内容，但把 `docs/README.md` 改为索引页，不再承担“默认入口”的角色。

- [ ] **Step 3: 清理重复文案**

检查 `docs/CI.md`、`docs/ENV-USAGE.md`、`nix/hosts/README.md` 是否有重复说明；只保留一个权威来源，其余改成链接。

- [ ] **Step 4: 明确自动化文档边界**

`AGENTS.md` / `CLAUDE.md` 留给自动化代理，不与面向人的 `README.md` / `docs/*` 相互复制。

- [ ] **Step 5: 验证**

手工检查首次访问仓库的路径：根目录 -> `README.md` -> `docs/*` -> 具体子目录 README，无死链。

### PR-6 验收标准

- 根目录存在人类入口文档
- 文档职责边界明确，不再多处重复维护同一段操作说明
- automation docs 与 human docs 分离

### PR-6 风险与回滚

- 风险：旧链接失效
- 控制：对保留文件做重定向说明，不立刻删除旧文档
- 回滚：文档改动独立，可单 PR 回退

## 验证矩阵

每个 PR 合并前至少执行以下最高信号检查：

```bash
just hosts
just eval-tests
just flake-check
just repo-check
```

按改动补充：

- PR-1: `bash nix/scripts/admin/install-live.sh --host zly --disk /dev/does-not-exist`
- PR-2: `just host=zly check && just darwin_host=zly-mac darwin-check`
- PR-3: 用一个测试 PR 验证 `ci-light.yml`
- PR-4: `bash nix/scripts/checks/unused-inputs.sh`
- PR-5: `bash nix/scripts/checks/registry-check.sh && just deploy HOSTS=zly`
- PR-6: 手工检查根 README 与 docs 链接

## 非目标

本轮不做：

- flake 输出结构重写
- `nix/modules/core` 大规模重命名/搬迁
- 一次性合并 NixOS 与 Darwin 的所有脚本逻辑
- 把所有文档重写成全新信息架构

## 完成定义

当以下条件同时满足时，本计划算完成：

- `justfile` 成为薄入口层
- 高风险命令具备明确确认与参数保护
- Light CI 至少能发现一个真实 Linux build 问题
- registry 字段被严格约束，deploy 语义完整
- flake inputs 有审计台账，删除动作可追溯
- 仓库根存在清晰的人类入口文档
