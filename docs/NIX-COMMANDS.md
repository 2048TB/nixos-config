# Nix 命令速查

优先使用 `just`，避免手写长命令。

---

## 1. 核心命令（NixOS）

```bash
just hosts
just host=zly check
just host=zly test
just host=zly switch
just host=zly boot
just rollback
```

说明：当前 `justfile` 默认 `host := ""`。未显式指定 `host` 时会自动检测当前主机。

---

## 2. 安装（Live ISO）

```bash
just host=zly install-check
just host=zly disk=/dev/nvme0n1 install
```

安装命令涉及分区与清盘，必须确认 `host` 和 `disk`。

---

## 3. macOS（nix-darwin）

```bash
just darwin-check
just darwin-switch
just darwin_host=zly-mac darwin-switch
```

---

## 4. 密钥管理（sops）

```bash
just sops-init-create
just sops-init
just sops-recovery-init
just password-hashes
just password-set-hash '<sha512-hash>'
just ssh-key-set
just sops-recipients
just sops-host-key-add <host> <pub>
just sops-rekey
```

---

## 5. 质量检查

```bash
just fmt
just lint
just dead
just eval-tests
just flake-check
just check-all
```

`check-all` 当前等价于：`fmt + lint + dead`（不包含 `eval-tests` 与 `flake-check`）。

---

## 6. Flake 与依赖

```bash
just update
just update-nixpkgs
just info
just lock
```

---

## 7. CI（GitHub Actions）

文档入口：`docs/CI.md`

常用命令：

```bash
# 触发工作流（指定分支）
gh workflow run "Nix CI Light" --ref <branch>
gh workflow run "Nix CI Heavy (Manual)" --ref <branch>
gh workflow run "Flake Lock Checker Heavy (Manual)" --ref <branch>
gh workflow run "Cleanup Old Workflow Runs" --ref <branch>

# 查看与跟踪运行
gh run list --limit 10
gh run watch <run-id>
gh run view <run-id> --log
```

---

## 8. 清理维护

```bash
just clean
just clean-all
just optimize
just clean-optimize
just disk
just generations
just diff
```

---

## 9. 远程部署（NixOS）

```bash
just deploy                  # 部署全部 NixOS hosts（按 registry）
just deploy HOSTS=zly,zky    # 只部署指定主机
```

`deploy` 会读取 `nixosConfigurations.<host>.config.my.host.deployHost/deployUser` 作为 SSH 目标。

---

## 10. Flake Apps

```bash
nix run .#apply
nix run .#build
nix run .#build-switch
nix run .#install   # Linux 平台
nix run .#clean
nix run .#deploy -- --hosts zly,zky
```

严格主机解析示例：
```bash
NIXOS_HOST=zky nix run .#build-switch
DARWIN_HOST=zly-mac nix run .#build-switch
```

---

## 11. 常见工作流

```bash
just quick                 # check + switch
just full                  # check-all + switch + clean
just dev                   # fmt + flake-check + test
just status && just log    # 查看仓库状态
```

---

## 12. 术语

| 术语 | 含义 |
|------|------|
| check | 构建检查，不切换 |
| test | 临时激活，重启失效 |
| switch | 正式切换，持久生效 |
| flake-check | 仓库级完整检查 |
| sops | 加密 secrets 管理 |
