# Cross-Platform Nix Config

最小可用的跨平台 Nix 仓库，当前包含：

- `nixosConfigurations`: `zky`、`zly`、`zzly`
- `darwinConfigurations`: `mbp-work`
- `homeConfigurations`: 独立 `home-manager` 调试入口

## 目录概览

- `flake.nix`: flake 输入与输出入口
- `nix/hosts/`: 每台主机自己的入口与参数
- `nix/nixos/`: NixOS 公共系统层
- `nix/darwin/`: nix-darwin 公共系统层
- `nix/home/`: 跨平台 `home-manager` 层
  - 其中用户层软件分组入口为 `nix/home/software.nix`
- `nix/registry/`: 当前 `flake` 实际读取的主机注册信息
- `nix/shared/`: 跨平台共享校验与文档渲染逻辑
- `configs/`: `niri` / `noctalia` 等用户配置源目录
- `secrets/`: `sops-nix` 加密文件
- `docs/`: 设计、计划与运维文档
  - 当前主机能力矩阵见 `docs/hosts.md`
  - 运行前检查、`resume` 自检、snapshot/rollback 入口见 `docs/operations.md`
- `scripts/`: 仓库运维脚本
  - `repo-check.sh`: 统一的仓库校验入口
  - `generate-hosts-doc.sh`: 重新生成 `docs/hosts.md`
  - `rebuild-host.sh`: 分阶段执行本机 `build` / `test` / `dry-activate` / `switch`
  - `deploy-host.sh`: 读取 registry 的远程部署入口
  - `install-nixos.sh`: 读取 registry 的 `nixos-anywhere` 安装入口
  - `preflight-switch.sh`: `switch` 前检查
  - `post-switch-check.sh`: `switch` 后运行态检查
  - `check-resume.sh`: Linux hibernate/resume 自检
  - `create-home-snapshot.sh`: 当前 Btrfs 布局下的 `/home` 手动快照

## 配置分层

- `roles`
  - 功能层
  - 例：`desktop`、`vpn`、`container`、`virt`
  - `desktop` 只提供图形会话与系统能力，不负责分发日常 GUI app
- `software`
  - 系统层软件开关
  - 例：`virtManager`、`virtViewer`、`dockerCompose`
- `homeSoftware`
  - 用户层软件开关
  - 例：`cli`、`desktopCore`、`browser`、`chat`、`remote`
  - `browser/chat/remote/desktopCore` 这类日常桌面软件统一放这里
  - 对应实现模块：`nix/home/software.nix`
- `dev-base`
  - 默认开发基础
  - 统一提供 `zig`、`uv`、`bun`、`go`、`nodejs`、`python3`、`rustc`、`cargo` 与 C 编译工具
- `languageTools`
  - Home Manager 补充语言工具开关
  - 当前用于控制 `go/node/rust/python` 的补充工具
- `go/node/rust/python`
  - 语言补充工具层
  - 例如 `gopls`、`pnpm`、`rustfmt`、`pip`

## 文档入口

- 运维命令、`switch`、`sops` key 部署与新增主机步骤见 [operations.md](/home/z/Downloads/1/docs/operations.md#L1)
- 当前主机能力矩阵见 [hosts.md](/home/z/Downloads/1/docs/hosts.md#L1)
- 仓库维护可直接使用：
  - `./scripts/repo-check.sh`
  - `./scripts/repo-check.sh --full`
  - `nix fmt`
  - `nix develop`
  - `nix flake check`
  - `./scripts/generate-hosts-doc.sh`
  - `./scripts/rebuild-host.sh`
  - `./scripts/deploy-host.sh`

## Legacy

- `legacy/` 是旧版 Home Manager 配置草稿，不在当前 `flake` 导入链里；当前生效入口以 `nix/hosts/`、`nix/nixos/`、`nix/darwin/`、`nix/home/` 为准。
