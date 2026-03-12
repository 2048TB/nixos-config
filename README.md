# nixos-config

最小化维护的 Nix 配置仓库。

当前仓库只保留少量脚本入口：
- 安装：`nix/scripts/admin/install-live.sh`
- filtered flake 路径：`nix/scripts/admin/print-flake-repo.sh`
- `flake.lock` 更新：`nix/scripts/admin/update-flake.sh`
- secrets / sops：`nix/scripts/admin/sops.sh`
- Git 密钥泄露保护：`nix/scripts/admin/guard-secrets.sh`

常用入口：
- 人类文档入口：`docs/README.md`
- 主机结构：`nix/hosts/README.md`
- Home Manager 结构：`nix/home/README.md`
- 命令速查：`docs/NIX-COMMANDS.md`

最常用命令：

```bash
just host=zly disk=/dev/nvme0n1 install
just update
just info
just sops-init-create
just guard-secrets
```

危险操作说明：
- `just install` 会清盘，并要求确认
- `sops.sh` 相关命令会改动仓库内密钥/secret 文件

安装、锁更新、filtered flake 使用方式与常见问题见 `docs/README.md`。
