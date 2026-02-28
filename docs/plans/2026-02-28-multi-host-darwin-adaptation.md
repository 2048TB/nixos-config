# Multi-Host + macOS Adaptation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在现有 `duozhuji` 改造基础上完成“多主机 + macOS”可持续维护结构，并把 `chaifen` 分支里的主机配置差异安全迁移到新结构。

**Architecture:** 保留当前 `hosts/ + outputs/<system>/src/ + lib/mk*Host` 分层，不引入新框架。借鉴参考仓库的点：按平台聚合输出、主机目录化、Darwin/NixOS 同构入口。只做最小 diff：补全主机迁移、修复 Darwin 装配 lint 阻塞、同步文档与命令入口。

**Tech Stack:** Nix flakes, nixosSystem, nix-darwin, Home Manager, just, statix/deadnix/nixpkgs-fmt.

---

### Task 1: 迁移并核对 `chaifen` 主机配置到新 `hosts/` 结构

**Files:**
- Modify: `hosts/nixos/zly/default.nix`
- Modify: `hosts/nixos/zly/hardware.nix`
- Modify: `hosts/nixos/zly/disko.nix`
- Modify: `hosts/nixos/zly/checks.nix`
- Reference-only: `chaifen:nix/hosts/zly.nix`
- Test: `outputs/x86_64-linux/tests/hostname/expected.nix`
- Test: `outputs/x86_64-linux/tests/home/expected.nix`

**Step 1: 先写/补 eval 断言，确保迁移前可捕获回归（失败用例）**

```nix
# outputs/x86_64-linux/tests/hostname/expected.nix
{ hostNames }: builtins.all (hn: builtins.elem hn hostNames) [ "zly" "zky" ]
```

**Step 2: 运行测试，确认在迁移未完成时失败（或至少暴露差异）**

Run: `nix eval .#checks.x86_64-linux.evaltest-hostname.drvPath`
Expected: 评估通过但后续 build 可能失败，或 hostname/home 断言与预期不一致。

**Step 3: 按最小差异迁移 `chaifen` 主机项到拆分文件**

```nix
# hosts/nixos/zly/default.nix
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../../modules/system.nix
    ../../../modules/hardware.nix
    ./hardware.nix
    ./disko.nix
  ];
}
```

**Step 4: 运行主机级检查验证迁移结果**

Run: `nix build --no-link .#checks.x86_64-linux.eval-zly-hostname .#checks.x86_64-linux.eval-zly-home-directory`
Expected: PASS。

**Step 5: Commit**

```bash
git add hosts/nixos/zly outputs/x86_64-linux/tests
git commit -m "refactor(hosts): align zly split modules with chaifen baseline"
```

### Task 2: 修复 Darwin 装配层 lint 阻塞，保证多主机 mac 配置可持续

**Files:**
- Modify: `lib/macosSystem.nix`
- Test: `hosts/darwin/zly-mac/checks.nix`
- Test: `outputs/aarch64-darwin/tests/home/expected.nix`

**Step 1: 先补结构化 `home` attr 的约束（失败用例）**

```nix
# 将重复 key 形式改成一个 attrset，便于 statix 验证
home = {
  username = lib.mkDefault mainUser;
  homeDirectory = lib.mkDefault "/Users/${mainUser}";
  stateVersion = lib.mkDefault "25.11";
};
```

**Step 2: 运行 lint，确认当前版本失败点**

Run: `just lint`
Expected: `lib/macosSystem.nix` 报重复 key（`home.*`）警告。

**Step 3: 以最小改动修复 `home-manager.users.<name>.home` 定义方式**

```nix
users.${mainUser} = {
  imports = homeModules;
  home = {
    username = lib.mkDefault mainUser;
    homeDirectory = lib.mkDefault "/Users/${mainUser}";
    stateVersion = lib.mkDefault "25.11";
  };
};
```

**Step 4: 验证 Darwin eval checks**

Run: `nix build --no-link .#checks.aarch64-darwin.evaltest-darwin-home .#checks.aarch64-darwin.eval-zly-mac-home-directory`
Expected: PASS。

**Step 5: Commit**

```bash
git add lib/macosSystem.nix
git commit -m "fix(darwin): normalize home attrs in macosSystem for statix"
```

### Task 3: 对齐多主机/mac 入口与文档（参考仓库的可操作入口）

**Files:**
- Modify: `outputs/default.nix`
- Modify: `outputs/README.md`
- Modify: `hosts/README.md`
- Modify: `justfile`
- Modify: `README.md`
- Modify: `NIX-COMMANDS.md`

**Step 1: 增加或确认主机发现入口命令与说明（失败用例）**

```bash
nix eval .#nixosConfigurations --apply builtins.attrNames
nix eval .#darwinConfigurations --apply builtins.attrNames
```

**Step 2: 先运行命令记录现状**

Run: `just hosts`
Expected: 列出 Linux + Darwin 主机集合。

**Step 3: 文档与命令最小同步（不做风格重写）**

```make
# justfile
nixos-hosts:
    nix eval path:/persistent/nixos-config#nixosConfigurations --apply builtins.attrNames

darwin-hosts:
    nix eval path:/persistent/nixos-config#darwinConfigurations --apply builtins.attrNames
```

**Step 4: 验证文档对应命令可执行**

Run: `just nixos-hosts && just darwin-hosts`
Expected: 输出与 `README/NIX-COMMANDS` 文档一致。

**Step 5: Commit**

```bash
git add outputs/README.md hosts/README.md justfile README.md NIX-COMMANDS.md
git commit -m "docs: sync multi-host and darwin operational workflow"
```

### Task 4: 端到端验证与回滚说明

**Files:**
- Verify-only: `flake.nix`
- Verify-only: `outputs/**`
- Verify-only: `hosts/**`
- Verify-only: `lib/**`

**Step 1: 格式化（若有变更）**

Run: `just fmt`
Expected: 无格式错误。

**Step 2: 静态检查**

Run: `just lint && just dead`
Expected: PASS。

**Step 3: Flake 级验证**

Run: `just flake-check`
Expected: PASS。

**Step 4: 构建验证（不切换）**

Run: `just check host=zly`
Expected: dry-build PASS。

**Step 5: 回滚预案记录**

```text
NixOS: sudo nixos-rebuild switch --rollback
Darwin: darwin-rebuild switch --rollback
```
