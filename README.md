# nixos-config

最小脚本 surface 的 Nix 配置仓库。

本页不是事实源。实际流程、脚本行为、风险边界与 FAQ 统一见 `docs/README.md`。

## 文档入口

- 权威手册：`docs/README.md`
- 环境差异：`docs/ENV-USAGE.md`
- 命令速查：`docs/NIX-COMMANDS.md`
- 快捷键摘要：`docs/KEYBINDINGS.md`
- 主机目录与 metadata：`nix/hosts/README.md`
- Home Manager 结构：`nix/home/README.md`
- 公钥与 secrets 流程：`secrets/keys/README.md`
- 代理规则：`AGENTS.md`、`CLAUDE.md`

## 当前保留入口

- 安装：`nix/scripts/admin/install-live.sh`
- filtered flake repo：`nix/scripts/admin/print-flake-repo.sh`
- `flake.lock` 更新：`nix/scripts/admin/update-flake.sh`
- secrets / sops：`nix/scripts/admin/sops.sh`
- Git secrets guard：`nix/scripts/admin/guard-secrets.sh`
- 格式/解析 sanity：`nix/scripts/admin/check-format-sanity.sh`
- `just`：build / check / switch / upgrade / clean / install 的主要入口

## 常用命令

```bash
just host=zly disk=/dev/nvme0n1 install
just update
just show
just self-check
just validate-local
just ml-shell
just mise-upgrade
just vpn-status
just host=zly check
just host=zly switch
just host=zly upgrade
just sops-init-create
just sops-rekey
just sops-recipients
just guard-secrets
```

## 本地验证基线

仓库当前以本地验证为准（不依赖 CI gate），推送前至少执行：

```bash
nix develop
just self-check
just validate-local
```

需要额外执行 check build 时再跑：

```bash
just validate-local-full
```

## 风险提示

- `install` / `install-live.sh` 会清盘
- `switch` / `boot` / `test` / `upgrade` 会直接改系统状态
- `sops.sh init --rotate` 会生成新 `main.agekey`
- `mise-upgrade` 会更新用户目录中的 flake 外工具版本
- `nix/home/configs/noctalia/` 当前按设计直接映射到 repo 工作树；GUI 改动会把其中 tracked config 弄脏
- `.keys/*.agekey` 不可提交；启用本地 hook 可执行 `just hooks-enable`

其余细节不在本页展开，统一以 `docs/README.md` 为准。
