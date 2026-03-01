# Nix 命令速查（新手版）

原则：优先使用 `just`，不要一上来手写长命令。

---

## 1. 先会这几个

```bash
just hosts
just check
just test
just switch
just boot
just rollback
just scripts-check
just eval-tests
just flake-check
just host=zly install-check
just host=zly disk=/dev/nvme0n1 install
```

说明：`switch`/`check`/`test`/`boot` 不指定 `host` 时自动检测当前主机（strict 模式）。
如果 hostname 不能匹配仓库主机，请设置 `NIXOS_HOST` 或用 `just host=xxx` 指定。

---

## 2. 安装相关（Live ISO）

```bash
# 目标主机 zly
just host=zly install-check
just host=zly disk=/dev/nvme0n1 install

# 目标主机 zky
just host=zky install-check
just host=zky disk=/dev/nvme0n1 install
```

安装命令必须指定 `host`（Live ISO hostname 不匹配仓库主机）。

说明：安装脚本会在 `nixos-install` 后把仓库同步到 `/persistent/nixos-config`，并修复 `/etc/nixos -> /persistent/nixos-config` 链接。

---

## 3. NixOS 日常维护

```bash
just check
just test
just switch
just boot

just host=zly switch
just host=zky switch
```

回滚与清理：

```bash
just rollback
just clean
just clean-all
just optimize
```

---

## 4. macOS（nix-darwin）

```bash
just darwin-check
just darwin-switch

just darwin_host=zly-mac darwin-check
just darwin_host=zly-mac darwin-switch
```

---

## 5. agenix（密码与密钥）

首次初始化（无旧密钥）：

```bash
just agenix-init-create
just agenix-recovery-init
```

已有旧密钥：

```bash
just agenix-init
```

更新系统密码：

```bash
just password-hashes
just password-set-hash '<sha512-hash>'
just switch
```

托管 GitHub SSH key：

```bash
just ssh-key-set
```

管理 recipients：

```bash
just agenix-recipients
just agenix-host-key-add zly /etc/ssh/ssh_host_ed25519_key.pub
just agenix-host-key-add zky /etc/ssh/ssh_host_ed25519_key.pub
just agenix-rekey
```

---

## 6. 质量检查

```bash
just fmt
just lint
just dead
just scripts-check
just eval-tests
just flake-check
```

---

## 7. 主机脚手架（新增主机）

```bash
just new-nixos-host devbox
just new-darwin-host mac-mini

just new-nixos-host-dry-run devbox
just new-darwin-host-dry-run mac-mini
```

---

## 8. flake apps（可选）

```bash
nix run .#apply
nix run .#build
nix run .#build-switch
nix run .#install
nix run .#clean
```

说明：`build` / `build-switch` / `apply` 默认 strict 主机解析（仅环境变量或当前 hostname）。
不再 fallback 到"第一个可用主机"。
其中 `build-switch` 会先执行构建检查（NixOS: `just check`；Darwin: `just darwin-check`），成功后再执行 switch。

指定主机：

```bash
NIXOS_HOST=zky nix run .#build-switch
DARWIN_HOST=zly-mac nix run .#build-switch
```

---

## 9. Git 同步

```bash
git status
git add -A
git commit -m "docs: update beginner docs"
git push origin HEAD
```

---

## 10. 术语（新手看）

- `check`：构建检查，不切换系统
- `test`：临时激活，重启后失效
- `switch`：正式切换并持久生效
- `flake-check`：仓库级检查（最全面）
- `agenix`：加密 secrets 管理工具
