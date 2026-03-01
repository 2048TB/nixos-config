# AGENTS.md（新手协作版）

本文件面向人类贡献者与自动化代理。
目标：让第一次接触本仓库的人，也能安全地改动并验证。

---

## 1. 先知道这是什么仓库

这是一个 flake-based 多主机配置仓库：
- NixOS 主机：`hosts/nixos/<host>/`
- macOS 主机：`hosts/darwin/<host>/`
- 聚合输出：`hosts/outputs/`
- 共享系统模块：`nix/modules/`
- 共享 Home Manager：`nix/home/`

---

## 2. 第一次贡献前，先跑这几个命令

```bash
just hosts
just eval-tests
just flake-check
```

如果你改了 Nix 文件，再补：

```bash
just fmt
just lint
```

---

## 3. 常用命令（优先记这几个）

```bash
just check-local
just test-local
just switch-local
just darwin-check-local
just darwin-switch-local
```

新增主机：

```bash
just new-nixos-host <name>
just new-darwin-host <name>
```

---

## 4. 目录改动指引（改哪里）

- 改某一台机器参数：`hosts/<platform>/<host>/vars.nix`
- 改系统行为（服务/内核/持久化）：`nix/modules/system.nix`（角色逻辑在 `system/role-flags.nix` 和 `system/role-services.nix`）
- 改硬件与显卡：`nix/modules/hardware.nix`
- 改用户应用与桌面：`nix/home/`
- 改主机发现或脚手架脚本：`scripts/resolve-host.sh`、`scripts/new-host.sh`

---

## 5. 文档同步硬规则

出现以下情况，必须同一变更中同步文档：

- 变更 Niri/Waybar/Tmux/Zellij 行为：同步 `README.md`、`KEYBINDINGS.md`、`NIX-COMMANDS.md`
- 变更主机发现或脚手架：同步 `README.md`、`hosts/README.md`、`hosts/outputs/README.md`、`NIX-COMMANDS.md`
- 变更流程规则：同步 `AGENTS.md` 与 `CLAUDE.md`

---

## 6. 提交规则

- 使用 Conventional Commit：`feat:`、`fix:`、`docs:`、`refactor:` 等
- 每次提交只做一个主题（例如“文档重写”不要混入系统逻辑变更）
- 用户要求同步 GitHub 时，执行 `git push origin HEAD`

---

## 7. 安全红线（必须遵守）

- 禁止提交任何私钥、token、明文密码
- `secrets/*.age` 可以提交；`.keys/*` 私钥绝对不能提交
- 涉及 `disko` / 安装流程命令，默认视为破坏性操作

与密码相关：
- 登录密码由 agenix secrets 管理：`secrets/passwords/user-password.age`、`secrets/passwords/root-password.age`

---

## 8. 变更原则

- 最小改动优先，不做无关重构
- 先保证正确性，再考虑性能与可维护性
- 有现成模式就复用，不重复造轮子

