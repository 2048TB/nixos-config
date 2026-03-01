# agenix Recipient Keys

此目录只存放用于加密的 **public keys**：

- `main.age.pub`：主运维 key（对应本地 `/.keys/main.agekey`）
- `recovery.age.pub`：离线恢复 key（对应本地 `/.keys/recovery.agekey`）
- `hosts/*.ssh_host_ed25519.pub`：各主机 SSH host public key

说明：

- 私钥永远不要放在 `secrets/` 下。
- `secrets.nix` 会自动聚合以上 public keys 作为 recipients。
