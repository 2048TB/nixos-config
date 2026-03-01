# CLAUDE.md（新手协作版）

本文件给 AI/自动化工具使用。
目标：在不破坏仓库稳定性的前提下，高效完成用户请求。

---

## 1. 工作边界

- 只做用户明确要求的改动
- 默认最小 diff
- 不做无关重构
- 中文说明，技术名词可用英文

---

## 2. 本仓库关键事实

- 多主机：`hosts/nixos/*` + `hosts/darwin/*`
- 聚合输出在：`hosts/outputs/`
- 共享模块：`nix/modules/`
- Home 配置：`nix/home/`
- 主机解析脚本：`scripts/resolve-host.sh`
- 主机脚手架脚本：`scripts/new-host.sh`

---

## 3. 必须保持的一致性

- 改 Niri/Waybar/Tmux/Zellij 行为：同步 `README.md`、`KEYBINDINGS.md`、`NIX-COMMANDS.md`
- 改主机发现/脚手架流程：同步 `README.md`、`hosts/README.md`、`hosts/outputs/README.md`、`NIX-COMMANDS.md`
- 改流程规则：同步 `CLAUDE.md` 和 `AGENTS.md`

---

## 4. 安全规则

- 禁止提交私钥、token、明文密码
- `secrets/*.age` 可提交，`.keys/*.agekey` 不可提交
- 涉及安装与分区（disko）命令时，默认视为危险操作

密码规则：
- 密码来源是 agenix：`secrets/passwords/user-password.age` 与 `secrets/passwords/root-password.age`
- 不使用 `/etc/*-password` 这类明文外部文件流程

---

## 5. 执行顺序（建议）

1. 先读相关文件，再动手修改
2. 优先改最少文件数
3. 改完后执行验证
4. 输出变更摘要 + 验证结果

---

## 6. 验证要求

文档改动至少执行：

```bash
just eval-tests
just flake-check
```

若改了 Nix 逻辑，再补：

```bash
just fmt
just lint
```

---

## 7. Git 同步规则

- 用户要求“同步到 GitHub”时：
  - 使用 Conventional Commit
  - `git push origin HEAD`
- 未被要求时，不主动推送

