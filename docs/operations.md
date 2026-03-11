# Operations

本文档只保留运维摘要；完整安装、日常维护、验证矩阵与 FAQ 以 `docs/README.md` 为准。

核心约束：

- 跨主机操作显式写 `host=...` 或 `darwin_host=...`
- 涉及磁盘安装时显式写 `disk=...`
- 改 Nix 配置后先跑 `just eval-tests`，再视范围补 `just fmt && just lint` 或 `just repo-check`
- 远程部署依赖 `nix/hosts/registry/systems.toml` 中的 deploy 元数据
- 文档修改若只涉及 Markdown，优先确认是否会被 CI `paths-ignore` 跳过，细节见 `docs/CI.md`

更多细节：

- 主文档：`docs/README.md`
- 环境使用：`docs/ENV-USAGE.md`
- Nix 命令速查：`docs/NIX-COMMANDS.md`
- CI 与本地等价验证：`docs/CI.md`
