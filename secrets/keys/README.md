# secrets/keys 说明（新手版）

这个目录只放 **public keys**（可以提交到 Git）。

---

## 1. 文件含义

- `main.age.pub`：主运维公钥
- `recovery.age.pub`：恢复公钥
- `hosts/*.ssh_host_ed25519.pub`：各主机 SSH host 公钥

---

## 2. 什么绝对不能放这里

- 私钥（`*.agekey`）
- 任意明文密码
- 任意私有 token

私钥只能放在本地仓库的 `./.keys/`（该目录被 `.gitignore` 忽略）。

---

## 3. 常用命令

```bash
# 初始化/同步主密钥（默认不创建）
just sops-init

# 首次创建主密钥
just sops-init-create

# 初始化 recovery key
just sops-recovery-init

# 添加主机 host 公钥作为 recipient
just sops-host-key-add zly /etc/ssh/ssh_host_ed25519_key.pub

# 重加密 secrets
just sops-rekey

# 查看 recipients
just sops-recipients
```

---

## 4. 工作原理（简版）

`nix/scripts/admin/sops.sh` 会读取本目录中的公钥集合，作为 `secrets/*.yaml` 的 recipients。
