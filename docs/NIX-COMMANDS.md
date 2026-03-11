# Nix 命令速查

只收录不适合放在主文档中的命令清单。日常 `check/test/switch`、安装步骤和 FAQ 统一见 `docs/README.md`。

---

## 1. 密钥管理（sops）

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

## 2. 质量检查

```bash
just fmt
just lint
just dead
just eval-tests
just flake-check
just repo-check
just check-all
```

`check-all` 当前等价于：`fmt + lint + dead`（不包含 `eval-tests` 与 `flake-check`）。
`repo-check` 会串联 shell syntax / shell tests / registry check / eval-tests / flake-check。

---

## 3. Flake 与依赖

```bash
just update
just update-nixpkgs
just info
just lock
```

---

## 4. CI（GitHub Actions）

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

## 5. 清理维护

```bash
just packages
just clean
just clean-all
just optimize
just clean-optimize
just disk
just generations
just diff
```

`just packages` 会同时显示：
- `environment.systemPackages`：系统/桌面运行基线
- 主用户 `home.packages`：Home Manager 提供的用户软件与开发环境

---

## 6. 远程部署（NixOS）

```bash
just deploy                  # 部署全部 NixOS hosts（按 registry）
just deploy HOSTS=zly,zky    # 只部署指定主机
```

`deploy` 会读取 `nix/hosts/registry/systems.toml` 中的 `deployEnabled` / `deployHost` / `deployUser` / `deployPort`；`deployEnabled = false` 时会跳过该主机，端口默认 `22`。

---

## 7. Flake Apps

```bash
nix run .#apply
nix run .#build
nix run .#build-switch
NIXOS_HOST=zly NIXOS_DISK_DEVICE=/dev/nvme0n1 nix run .#install
nix run .#clean
nix run .#deploy -- --hosts zly,zky
```

严格主机解析示例：
```bash
NIXOS_HOST=zky nix run .#build-switch
DARWIN_HOST=zly-mac nix run .#build-switch
```

---

## 8. 术语

| 术语 | 含义 |
|------|------|
| check | 构建检查，不切换 |
| test | 临时激活，重启失效 |
| switch | 正式切换，持久生效 |
| flake-check | 仓库级完整检查 |
| sops | 加密 secrets 管理 |
