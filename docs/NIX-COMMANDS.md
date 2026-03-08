# Nix 命令速查

优先使用 `just`，不要手写长命令。

---

## 1. 核心命令

```bash
just hosts                              # 列出所有主机
just check                              # 构建检查（不切换）
just test                               # 临时激活（重启失效）
just switch                             # 正式切换
just boot                               # 下次启动生效
just rollback                           # 回滚
```

不指定 `host` 时自动检测（strict 模式）。指定：`just host=xxx <command>`

---

## 2. 安装（Live ISO）

```bash
just host=zly install-check             # 预检
just host=zly disk=/dev/nvme0n1 install # 安装（清盘）
```

安装命令必须指定 `host`。

---

## 3. macOS

```bash
just darwin-check
just darwin-switch
just darwin_host=zly-mac darwin-switch
```

---

## 4. 密钥管理（sops）

```bash
just sops-init-create         # 首次创建主密钥
just sops-init                # 同步已有密钥
just sops-recovery-init       # 初始化恢复密钥
just password-hashes          # 生成密码哈希
just password-set-hash '<h>'  # 写入密码
just ssh-key-set              # 托管 SSH key
just sops-recipients          # 查看 recipients
just sops-host-key-add <host> <pub>  # 添加主机公钥
just sops-rekey               # 重加密所有 secrets
```

---

## 5. 质量检查

```bash
just fmt              # 格式化
just lint             # 静态检查
just dead             # 死代码检测
just eval-tests       # eval 测试
just flake-check      # flake 完整检查
just check-all        # 以上全部
```

---

## 6. 新增主机（手动）

```bash
cp -a nix/hosts/nixos/zly nix/hosts/nixos/devbox
cp -a nix/hosts/darwin/zly-mac nix/hosts/darwin/mac-mini
```

复制后请手动修改 `vars.nix` 里的 `gpuMode` / `*BusId` 等字段。

`gpuMode` 可选：
- `auto`（默认，按 `lspci` 自动识别）
- `none` / `modesetting`
- `amd` / `amdgpu`
- `nvidia` / `nvidia-prime`
- `amd-nvidia-hybrid`

混合显卡模式需要手动填写 `vars.nix` 中的 `intelBusId` / `amdgpuBusId` / `nvidiaBusId`（格式：`PCI:<bus>:<device>:<function>`）。

---

## 7. 清理维护

```bash
just clean           # 清理 7 天前旧世代
just clean-all       # 仅保留当前世代
just optimize        # 硬链接优化
just disk            # 查看存储使用
just generations     # 列出世代
just diff            # 对比最近两个世代
```

---

## 8. Flake Apps

```bash
nix run .#apply           # switch
nix run .#build           # check
nix run .#build-switch    # check + switch
nix run .#install         # 安装
nix run .#clean           # 清理
```

主机解析为 strict 模式。指定：`NIXOS_HOST=zky nix run .#build-switch`

---

## 9. 术语

| 术语 | 含义 |
|------|------|
| check | 构建检查，不切换 |
| test | 临时激活，重启失效 |
| switch | 正式切换，持久生效 |
| flake-check | 仓库级完整检查 |
| sops | 加密 secrets 管理 |
