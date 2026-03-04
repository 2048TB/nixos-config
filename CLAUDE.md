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

多主机配置：
- `hosts/nixos/<host>/`：NixOS 主机（必须含 `hardware.nix` + `disko.nix` + `vars.nix`）
- `hosts/darwin/<host>/`：macOS 主机（必须含 `default.nix` + `vars.nix`）
- `hosts/nixos/_shared/`：NixOS 共享模板（hardware/disko/checks）
- `hosts/outputs/`：flake 输出聚合层（自动发现主机，无需手动注册）

共享模块：
- `nix/modules/system/`：系统核心（入口 `default.nix`；含 boot/services/desktop/security/storage 等子模块）
- `lib/default.nix` 中的 `roleFlags`：角色标志（desktop/gaming/vpn/virt/container）
- `nix/modules/system/role-services.nix`：角色服务（Steam/Docker/Provider app/libvirt）
- `nix/modules/hardware.nix`：GPU/蓝牙/固件
- `nix/home/base/`：跨平台共享（session 变量 + PATH）
- `nix/home/linux/`：Linux 专用（default/packages/programs/desktop/xdg 五个文件）
- `nix/home/darwin/`：macOS 专用

脚本（`scripts/`）：
- `agenix.sh`：密钥管理（init/password-set/ssh-key-set/recovery-init/host-add/recipients/rekey）
- `install-live.sh`：Live ISO 安装（disko → rsync → agenix key → nixos-install）
- `resolve-host.sh`：主机自动识别（env → hostname → fallback，支持 --strict）
- `new-host.sh`：主机脚手架（从模板复制 + sed 替换主机名）
- `common.sh`：共享 helpers（run_agenix/run_age_keygen/run_agenix_encrypt 等）
- `guard-secrets.sh`：密钥泄露防护（路径 + 内容双重检查）
- `check-scripts.sh`：脚本语法 + shellcheck

其他：
- `lib/`：Nix 库函数（mkNixosHost/mkDarwinHost/scanPaths/discoverHostNamesBy）
- `secrets.nix`：agenix recipients 配置（自动聚合 main + recovery + host 公钥）
- `.keys/`：本地私钥（.gitignore 忽略，不可提交）

---

## 3. 必须保持的一致性

- 改快捷键行为（Niri/Tmux/Zellij）：同步 `KEYBINDINGS.md`
- 改主机发现/脚手架/安装流程：同步 `README.md`、`hosts/README.md`、`NIX-COMMANDS.md`
- 改 justfile 命令或 flake apps：同步 `NIX-COMMANDS.md`、`ENV-USAGE.md`
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

