# nixos-config

多主机 Nix 配置仓库，包含：

- NixOS: `zly`、`zky`、`zzly`
- nix-darwin: `zly-mac`
- Home Manager 分层配置

常用入口：

- 人类文档入口: `docs/README.md`
- CI 摘要: `docs/ci.md`
- CI 详细说明: `docs/CI.md`
- 主机结构: `nix/hosts/README.md`
- Home Manager 结构: `nix/home/README.md`
- 命令速查: `docs/NIX-COMMANDS.md`

高频命令：

```bash
just hosts
just eval-tests
just flake-check
just repo-check
just host=zly check
just host=zly switch
```

危险操作说明：

- `just install` 会清盘，并要求确认
- `just clean-all` 会删除旧 generations，并要求确认
- `just deploy` 读取 `nix/hosts/registry/systems.toml` 中的 deploy 元数据

进一步说明见 `docs/README.md`。
