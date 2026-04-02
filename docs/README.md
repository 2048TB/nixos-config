# Docs

本文是当前仓库的唯一事实源。其余文档只做入口、主题说明或代理规则，不重复维护完整事实。

## 文档地图

| 文档 | 职责 |
|------|------|
| `README.md` | 仓库根入口与最短提示 |
| 本文档 | 权威手册：流程、脚本行为、约束、FAQ |
| `docs/NIX-COMMANDS.md` | 纯命令速查 |
| `docs/ENV-USAGE.md` | 环境差异 |
| `docs/KEYBINDINGS.md` | 快捷键摘要 |
| `nix/hosts/README.md` | hosts 目录、registry 与结构入口 |
| `nix/home/README.md` | Home Manager 结构入口 |
| `secrets/keys/README.md` | 公钥目录与 key 操作入口 |
| `AGENTS.md` / `CLAUDE.md` | 代理规则与文档同步要求 |

## 1. 仓库现状

当前仓库只保留少量运维脚本入口：

- `nix/scripts/admin/install-live.sh`
- `nix/scripts/admin/print-flake-repo.sh`
- `nix/scripts/admin/update-flake.sh`
- `nix/scripts/admin/sops.sh`
- `nix/scripts/admin/guard-secrets.sh`
- `nix/scripts/admin/common.sh`

常用 build / check / switch / upgrade / clean 入口通过 `just` 暴露。当前 CI 只保留两类工作：

- manual `flake.lock` freshness check
- schedule/manual workflow run cleanup

## 2. 全局约定

- 危险操作必须显式写 `host=...`、`disk=...` 或 `--repo <path>`
- 显式传入的 `--repo` / `NIXOS_CONFIG_REPO` 若无效，脚本会直接失败，不会静默回退
- read-only `eval` / `show` / `build` 优先通过 filtered flake repo，避免直接触碰不可读的 `.keys/main.agekey`
- `sops.sh` 与 `guard-secrets.sh` 可以从仓库外直接调用
- `nix/hosts/registry/systems.toml` 是 host metadata 的事实源
- `displays` metadata 是 monitor topology 的事实源；不要再在别处重复手写 connector facts
- `nix/home/configs/noctalia/` 当前按设计直接映射到 repo 工作树；GUI 改动会直接改动 tracked config

## 3. 最常用命令

```bash
just host=zly disk=/dev/nvme0n1 install
just update
just update-nixpkgs
just info
just show
just flake-check
just host=zly check
just host=zly switch
just host=zly upgrade
just clean
just sops-init-create
just sops-init-rotate
just sops-recipients
just sops-rekey
just guard-secrets
```

命令细表见 `docs/NIX-COMMANDS.md`。

## 4. Read-Only Flake 使用

如果真实 checkout 中存在不可读的 `.keys/main.agekey`，不要直接对原始 `path:/persistent/nixos-config` 做 read-only 操作。先取 filtered repo：

```bash
REPO=/persistent/nixos-config
flake_repo="$(bash "$REPO/nix/scripts/admin/print-flake-repo.sh" "$REPO")"
nix flake show "path:$flake_repo"
```

`print-flake-repo.sh` 的当前行为：

- 输出一个复制自当前工作树的临时 flake repo
- 显式排除 `.keys/`、`.git/`、`.cache/` 与 `result*`
- 适合 `nix flake show`、`nix eval`、`nix build`、`nix flake check --no-build`
- 对显式传错的 repo 路径直接报错

## 5. 安装流程

### 5.1 Live ISO 最短流程

```bash
git clone https://github.com/2048TB/nixos.git ~/nixos
cd ~/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
nix shell nixpkgs#just -c just sops-init-create
nix shell nixpkgs#just -c just sops-recovery-init
nix shell nixpkgs#just -c just password-hashes
nix shell nixpkgs#just -c just host=zly disk=/dev/nvme0n1 install
```

若已有旧 `main.agekey`，先放到以下任一位置，再执行 `just sops-init`：

- `./.keys/main.agekey`
- `<repo>/.keys/main.agekey`
- `~/.keys/main.agekey`

### 5.2 `install-live.sh` 的当前行为

```bash
bash nix/scripts/admin/install-live.sh --host zly --disk /dev/nvme0n1 --repo "$PWD"
```

- 用法：`install-live.sh --host <name> --disk <device> [--repo <path>] [--yes]`
- 会要求确认；自动化环境可用 `--yes`
- 会清空目标盘并运行 `disko`
- 会把仓库同步到目标系统的 `/persistent/nixos-config`
- 会把 `/etc/nixos` 链接到 `/persistent/nixos-config`
- 会执行一次 `nixos-rebuild dry-build`
- 安装 `main.agekey` 前，会校验该 private key 派生出的 public key 是否与 `<repo>/secrets/keys/main.age.pub` 一致

`install-live.sh` 的 key 搜索顺序仍是：

- `./.keys/main.agekey`
- `<repo>/.keys/main.agekey`
- `~/.keys/main.agekey`

但现在只有“与仓库 `main.age.pub` 匹配”的 key 才会被接受；找到了无关键也会直接失败。

环境差异和手动安装路径见 `docs/ENV-USAGE.md`。

## 6. Lock / Eval / Build / Switch

更新输入：

```bash
just update
just update-nixpkgs
```

只读信息：

```bash
just info
just show
just metadata
just hosts
just flake-check
```

系统级入口：

```bash
just host=zly build
just host=zly dry-build
just host=zly check
just host=zly switch
just host=zly boot
just host=zly test
just host=zly upgrade
```

当前行为说明：

- `build` / `dry-build` 会先取 filtered repo，再做只读构建
- `check` 走 `sudo nixos-rebuild dry-build --flake ...`
- `switch` / `boot` / `test` 会直接改系统状态
- `upgrade` 现在会保留外层 `repo={{repo}}`，先在指定 repo 上执行 `update`，再执行 `switch`
- `flake-check` 做 `nix flake check --all-systems --no-build`

清理相关：

```bash
just gc
just clean
just clean-all
just optimize
just use
```

## 7. Secrets 与 Git 安全

### 7.1 常用入口

```bash
just hooks-enable
just guard-secrets
just sops-init
just sops-init-create
just sops-init-rotate
just sops-recovery-init
just sops-recipients
just sops-rekey
just ssh-key-set
just password-set-hash '<sha512-hash>'
```

### 7.2 `sops.sh` 的当前行为

- `init`：同步已有 `main.agekey`
- `init --create`：创建新的 `main.agekey`
- `init --rotate [--yes]`：生成新的 `main.agekey`，更新 `secrets/keys/main.age.pub`，并保留旧 key 为 `.keys/main.agekey.pre-rotate.<timestamp>`
- `rekey`：基于当前 `main.agekey`、`recovery.agekey` 和现存 rotation backup keys 构造 identity file，然后对每个 secret 执行 `sops rotate -i --add-age/--rm-age`
- `recipients`：列出当前收件人
- `host-key-add`：把 host SSH public key 同步到 `secrets/keys/hosts/`

注意：

- `just sops-init-rotate` 只是交互式入口；需要非交互确认时，直接调用 `nix/scripts/admin/sops.sh init --rotate --yes`
- rotation 完成后，旧 backup key 仍需保留到 `rekey` 和部署完成
- `run_sops_encrypt_yaml` 现在先写临时文件，再原子替换，避免加密失败时截断原 secret

### 7.3 私钥与公钥边界

- `secrets/keys/` 只放可提交的 public keys
- `.keys/*.agekey` 不可提交
- 运行时主密钥目标路径：`/persistent/keys/main.agekey`
- `guard-secrets.sh` 应作为提交前 guard，而不是事后补救

## 8. Host Metadata 与桌面约束

- host metadata 事实源：`nix/hosts/registry/systems.toml`
- 常见字段：`system`、`kind`、`formFactor`、`desktopSession`、`desktopProfile`、`tags`、`gpuVendors`、`displays`、deploy metadata
- `roles` 是功能开关；不要重新引入旧 `profiles` 模型
- `tags` 只保留无法稳定派生的事实；`multi-monitor` / `hidpi` 不再手写
- `displays.primary` 现在必须是 `bool`
- `displays.match` 现在必须是 `string` 或 `null`
- Linux `desktopProfile` 当前只支持 `niri`
- `nix/home/configs/noctalia/settings.json` 会因为 GUI 改动直接漂移；这是当前保留设计，不是文档错误

## 9. FAQ

### 9.1 `nix eval path:/persistent/nixos-config#...` 报 `.keys/main.agekey: Permission denied`

先执行：

```bash
flake_repo="$(bash /persistent/nixos-config/nix/scripts/admin/print-flake-repo.sh /persistent/nixos-config)"
```

再对 `path:$flake_repo#...` 执行 `eval` / `show` / `build`。

### 9.2 `just update` 失败

确认 repo 可写，且 `flake.lock` 不是只读。`update-flake.sh` 会在需要时先更新 filtered repo，再同步回真实仓库。

### 9.3 传了 `--repo` 仍操作错仓库

按当前实现，不会。显式传错路径会直接失败；若行为看起来异常，优先检查你传入的 `--repo` / `NIXOS_CONFIG_REPO`。

### 9.4 找不到 `main.agekey`

放到以下任一位置：

- `./.keys/main.agekey`
- `<repo>/.keys/main.agekey`
- `~/.keys/main.agekey`

### 9.5 如何做非交互 rotate

```bash
bash nix/scripts/admin/sops.sh init --rotate --yes
bash nix/scripts/admin/sops.sh rekey
```

### 9.6 如何防止密钥泄露

```bash
just hooks-enable
just guard-secrets
```
