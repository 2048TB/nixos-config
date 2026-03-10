# Operations

## 常用验证

查看 flake 输出：

```bash
nix flake show --all-systems
```

进入仓库维护环境：

```bash
nix develop
```

统一仓库校验：

```bash
./scripts/repo-check.sh
./scripts/repo-check.sh --full
```

其中：

- 默认模式检查 `scripts/*.sh` 语法、Nix formatting、`docs/hosts.md` 漂移和 `nix flake check`
- `--full` 额外执行所有当前 host 的 `dry-run`

格式化当前仓库：

```bash
nix fmt
```

验证 Linux 主机：

```bash
nix build --dry-run .#nixosConfigurations.zky.config.system.build.toplevel
nix build --dry-run .#nixosConfigurations.zly.config.system.build.toplevel
nix build --dry-run .#nixosConfigurations.zzly.config.system.build.toplevel
```

验证 macOS 主机：

```bash
nix build --dry-run '.#darwinConfigurations.mbp-work.system'
```

验证独立 Home Manager：

```bash
nix build --dry-run '.#homeConfigurations."z@mbp-work".activationPackage'
```

当前共享校验会在 `eval` 阶段直接阻止以下漂移：

- `nix/registry/systems.toml` 和 host `vars.nix` 的重叠字段不一致
- 不支持的 `formFactor` / `languageTools` / `cpuVendor` / `gpuMode` / `dockerMode`
- `container` role 与 `dockerMode` 的不一致
- 当前 Btrfs swapfile 布局下缺失 `diskDevice` / `swapSizeGb` / `resumeOffset`
- `preflight-switch.sh` 还会额外阻止 `docs/hosts.md` 与真实 host inventory 的漂移

## 切换配置

NixOS：

```bash
./scripts/preflight-switch.sh nixos zky
./scripts/rebuild-host.sh nixos zky build
./scripts/rebuild-host.sh nixos zky test
./scripts/rebuild-host.sh nixos zky dry-activate
./scripts/rebuild-host.sh nixos zky switch

./scripts/preflight-switch.sh nixos zly
./scripts/rebuild-host.sh nixos zly build
./scripts/rebuild-host.sh nixos zly test
./scripts/rebuild-host.sh nixos zly dry-activate
./scripts/rebuild-host.sh nixos zly switch

./scripts/preflight-switch.sh nixos zzly
./scripts/rebuild-host.sh nixos zzly build
./scripts/rebuild-host.sh nixos zzly test
./scripts/rebuild-host.sh nixos zzly dry-activate
./scripts/rebuild-host.sh nixos zzly switch
```

macOS：

```bash
./scripts/preflight-switch.sh darwin mbp-work
./scripts/rebuild-host.sh darwin mbp-work build
./scripts/rebuild-host.sh darwin mbp-work switch
```

仅切换 Home Manager：

```bash
home-manager switch --flake '.#z@mbp-work'
home-manager switch --flake '.#z@template-linux'
```

`resume` 配置检查：

```bash
./scripts/check-resume.sh zky
./scripts/check-resume.sh zly
./scripts/check-resume.sh zzly
```

当前 `check-resume.sh` 会检查：

- 配置里的 `boot.resumeDevice`
- 配置里的 `resume_offset`
- 若在目标 Linux 主机本机执行，再检查运行态根设备、内核命令行中的 `resume_offset`、以及 `/sys/power/state` 是否包含 `disk`

切换后运行态检查：

```bash
./scripts/post-switch-check.sh nixos zky
./scripts/post-switch-check.sh nixos zly
./scripts/post-switch-check.sh nixos zzly

./scripts/post-switch-check.sh darwin mbp-work
```

远程部署：

```bash
./scripts/deploy-host.sh nixos zky
./scripts/deploy-host.sh nixos zly
./scripts/deploy-host.sh nixos zzly

./scripts/deploy-host.sh darwin mbp-work
```

说明：

- NixOS 远程部署使用 `nixos-rebuild --target-host`
- Darwin 当前只支持在目标主机本机执行 `deploy-host.sh`
- `deployHost` / `deployUser` 取自 `nix/registry/systems.toml`

## Snapshot / Rollback

当前 NixOS 公共层已默认启用：

- `snapper` 根子卷 timeline snapshots
- `btrfs` scrub
- `nh`

查看根子卷 snapshots：

```bash
sudo snapper -c root list
```

在切换前手动打一个快照：

```bash
sudo snapper -c root create --description "before-switch"
```

按当前磁盘布局手动保存 `/home` 只读快照：

```bash
sudo ./scripts/create-home-snapshot.sh before-switch
```

手动回滚时建议先从 live environment 或单用户环境确认目标 snapshot，再执行 `snapper rollback`；这一步是 destructive 操作，不提供仓库脚本封装。

## SOPS Key

当前仓库使用同一把 `age` 私钥解密 `sops` 文件。
当前共享 secrets 文件是 `secrets/common.yaml`。
当前 host-specific secrets 文件是 `secrets/nixos/<host>.yaml` 与 `secrets/darwin/<host>.yaml`。
共享密码类 secrets 明确绑定到 `secrets/common.yaml`；host-only secrets 应在 `nix/hosts/nixos/<host>/secrets.nix` 中声明，并显式使用该 host 的 `sopsFile`。

导出的私钥文件：

- `./sops-age-key.txt`

NixOS 目标主机安装位置：

- `/var/lib/sops-nix/key.txt`

Darwin 用户默认位置：

- `/Users/<user>/Library/Application Support/sops/age/keys.txt`

安装命令：

```bash
sudo ./scripts/install-sops-age-key.sh ./sops-age-key.txt
```

目标机常见检查：

```bash
sudo test -f /var/lib/sops-nix/key.txt
sudo test "$(stat -c '%a' /var/lib/sops-nix/key.txt)" = "600"
```

验证 secrets 可解密：

```bash
SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt sops decrypt ./secrets/common.yaml
```

当前密码 secret：

- `password_root_hash`
- `password_z_hash`

对应配置接线：

- `users.users.root.hashedPasswordFile`
- `users.users.z.hashedPasswordFile`

注意：

- `sops-age-key.txt` 已加入 `.gitignore`，不要提交到仓库
- 若后续切换到“每台主机独立 key”，需要同步更新 `.sops.yaml`

## Host Matrix

`docs/hosts.md` 现在是生成产物，不再手写维护。

重新生成：

```bash
./scripts/generate-hosts-doc.sh
```

生成来源：

- `nix/registry/systems.toml`
- `nix/hosts/*/*/vars.nix`

## 软件分层规则

- `roles`
  - 放功能能力
  - 例：`desktop`、`vpn`、`container`、`virt`
  - `desktop` 负责 greetd、niri、portal、audio 等系统能力
- `software`
  - 放系统层软件开关
  - 例：`virtManager`、`virtViewer`、`dive`
- `homeSoftware`
  - 放用户层 package 分组
  - 例：`cli`、`desktopCore`、`browser`、`chat`、`remote`
  - 浏览器、聊天、远程管理、终端工具优先放这里，不再塞回系统 role
  - 对应实现模块：`nix/home/software.nix`
- `dev-base`
  - 放所有开发主机默认需要的基础语言工具链与 C 编译工具
- `languageTools`
  - 放 Home Manager 补充语言工具模块开关
  - 当前用于控制 `go/node/rust/python` 的补充工具模块
- `go/node/rust/python`
  - 放语言专属补充工具，不再承担语言本体安装
- `formFactor`
  - 只表示主机形态，不参与 Home Manager 模块装配
- 当前各主机默认值总览见 `docs/hosts.md`

## 新增主机

新机安装：

```bash
./scripts/install-nixos.sh zky
./scripts/install-nixos.sh zky --vm-test
./scripts/install-nixos.sh zky --execute
```

说明：

- 该脚本封装 `nixos-anywhere`
- 默认只打印命令，不执行 destructive install
- 只有加上 `--execute` 才会真正执行安装
- 安装目标默认取自 `nix/registry/systems.toml` 中对应 host 的 `deployHost` / `deployUser`

新增 NixOS 主机最小步骤：

1. 复制 `nix/hosts/nixos/<host>/`
2. 填写 `vars.nix`
3. 选择 `hardware-modules.nix`
4. 调整 `hardware.nix`
5. 调整 `disko.nix`
6. 在 `nix/registry/systems.toml` 中纳入主机，并补齐对应 `nix/hosts/.../<host>/`
7. 先执行 `nix build --dry-run .#nixosConfigurations.<host>.config.system.build.toplevel`

新增 darwin 主机最小步骤：

1. 复制 `nix/hosts/darwin/<host>/`
2. 填写 `vars.nix`
3. 根据需要调整 host-specific `home.nix`
4. 在 `nix/registry/systems.toml` 中纳入主机，并补齐对应 `nix/hosts/.../<host>/`
5. 先执行 `nix build --dry-run '.#darwinConfigurations.<host>.system'`

## 当前已知范围

- 当前验证主要是 `eval` 和 `dry-run`
- 不等于已经在真实机器执行过 `switch`
- CI 当前只验证语法、`flake check` 和 `dry-run`，不解密 secrets
- 若改动 `configs/niri`、`configs/noctalia`、`configs/fuzzel`、`configs/ghostty`、`configs/yazi`，应额外做桌面实机验证
