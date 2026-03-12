# nixos-config

最小化维护的 Nix 配置仓库。

当前仓库只保留少量脚本入口：
- 安装：`nix/scripts/admin/install-live.sh`
- filtered flake 路径：`nix/scripts/admin/print-flake-repo.sh`
- `flake.lock` 更新：`nix/scripts/admin/update-flake.sh`
- secrets / sops：`nix/scripts/admin/sops.sh`
- Git 密钥泄露保护：`nix/scripts/admin/guard-secrets.sh`

当前 CI 只保留两项：
- 手动触发的 `flake.lock` 新鲜度检查
- 定时/手动触发的旧 workflow run 清理

文档分工：
- `docs/README.md`：权威运维手册（安装、锁更新、secrets、FAQ）
- `docs/ENV-USAGE.md`：按环境区分的差异说明
- `docs/NIX-COMMANDS.md`：纯命令速查
- `nix/hosts/README.md`：主机目录与 metadata
- `nix/home/README.md`：Home Manager 结构

最常用命令：

```bash
just host=zly disk=/dev/nvme0n1 install
just update
just info
just host=zly switch
just clean
just sops-init-create
just guard-secrets
```

危险操作说明：
- `just install` 会清盘，并要求确认
- `just switch` / `just boot` / `just test` 会直接改当前系统状态，必须显式传 `host=...`
- `sops.sh` 相关命令会改动仓库内密钥/secret 文件

具体操作、环境差异和 FAQ 不在本页展开，统一见 `docs/README.md`。
