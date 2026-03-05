# 多环境使用手册

按 3 种环境拆分：Live ISO / 已安装 NixOS / macOS

---

## 通用约定

推荐仓库路径：`/persistent/nixos-config`

主机解析优先级：
1. 显式指定（`just host=xxx`）
2. 环境变量（`NIXOS_HOST` / `DARWIN_HOST`）
3. 当前 hostname

不匹配时报错（strict 模式），不做 fallback。安装命令必须显式指定 host。

---

## 1. Live ISO（安装 NixOS）

### 启用 flakes

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

### 安装

```bash
nix shell nixpkgs#just -c just hosts
just host=zly disk=/dev/nvme0n1 install
```

### 密钥搜索路径

`./.keys/main.agekey` → `<repo>/.keys/main.agekey` → `~/.keys/main.agekey`（需为 `AGE-SECRET-KEY-*` 私钥）

---

## 2. 已安装 NixOS

### 日常更新

```bash
just check && just test && just switch
```

### 指定主机

```bash
just host=zly switch
```

### 质量检查

```bash
just scripts-check && just eval-tests && just flake-check
```

### 回滚与清理

```bash
just rollback
just clean
```

---

## 3. macOS（nix-darwin）

```bash
just darwin-check
just darwin-switch
just darwin_host=zly-mac darwin-switch
```

Flake apps：

```bash
nix run .#build-switch
DARWIN_HOST=zly-mac nix run .#build-switch
```

---

## 4. 常见报错

| 报错 | 处理 |
|------|------|
| `strict mode requires a valid host` | `just hosts` 查看主机，`just host=xxx` 指定 |
| 找不到 `main.agekey` | 放到 `.keys/` 目录 |
| 密码不生效 | `just password-set-hash '<hash>' && just switch` |
