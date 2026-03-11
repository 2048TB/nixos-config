# nixos-config

多主机 Nix 配置仓库，包含：

- NixOS: `zly`、`zky`、`zzly`
- nix-darwin: `zly-mac`
- Home Manager 分层配置

常用入口：

- 人类文档入口: `docs/README.md`
- CI 说明: `docs/CI.md`
- 主机结构: `nix/hosts/README.md`
- Home Manager 结构: `nix/home/README.md`
- 命令速查: `docs/NIX-COMMANDS.md`

日常入口：

```bash
just hosts
just eval-tests
just host=<nixos-host> check
just host=<nixos-host> switch
```

危险操作说明：

- `just install` 会清盘，并要求确认
- `just clean-all` 会删除旧 generations，并要求确认
- `just deploy` 读取 `nix/hosts/registry/systems.toml` 中的 deploy 元数据

安装、日常维护、验证矩阵与常见问题统一见 `docs/README.md`。
