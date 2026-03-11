# Operations

日常操作优先使用 `just`，并尽量显式指定目标主机。

常用命令：

```bash
just hosts
just host=zly check
just host=zly switch
just eval-tests
just repo-check
```

操作约束：

- 跨主机操作显式写 `host=...` 或 `darwin_host=...`
- 涉及磁盘安装时显式写 `disk=...`
- 改 Nix 配置后先跑 `just eval-tests`，再视范围补 `just fmt && just lint` 或 `just repo-check`
- 远程部署依赖 `nix/hosts/registry/systems.toml` 中的 deploy 元数据

更多细节：

- 环境使用：`docs/ENV-USAGE.md`
- Nix 命令速查：`docs/NIX-COMMANDS.md`
- CI 与本地等价验证：`docs/CI.md`
