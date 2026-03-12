# AGENTS.md

面向人类贡献者与自动化代理。目标：安全地改动并验证。

---

## 1. 事实源与入口

- 运维主文档：`docs/README.md`
- 环境差异：`docs/ENV-USAGE.md`
- 命令速查：`docs/NIX-COMMANDS.md`
- 主机目录与 metadata：`nix/hosts/README.md`
- NixOS 主机模板：`nix/hosts/nixos/README.md`
- Home Manager 结构：`nix/home/README.md`
- secrets/public keys：`secrets/keys/README.md`
- 当前保留脚本：`nix/scripts/admin/{install-live,print-flake-repo,update-flake,sops,guard-secrets,common}.sh`
- 当前 CI：manual `flake.lock` freshness check + schedule/manual workflow run cleanup

---

## 2. Host Metadata 模型

- host metadata 事实源：`nix/hosts/registry/systems.toml`
- registry 字段：`system`、`kind`、`formFactor`、`desktopSession`、`desktopProfile`、`tags`、`gpuVendors`、`displays`、deploy 元数据
- 模块消费路径：`registry -> my.host -> my.capabilities`
- Linux NixOS/Home Manager 入口默认走 auto-discovered `_mixins`
- `roles` 是功能开关；不要重新引入旧 `profiles` 模型，也不要把 machine topology 塞进 `roles`
- `tags` 只保留无法稳定派生的事实；`multi-monitor` / `hidpi` 这类 display facts 不再手写
- 不要在桌面配置里硬编码 monitor 名称；优先从 registry `displays` metadata 生成
- Linux `desktopProfile` 当前只支持 `niri`；Darwin 使用 `aqua`
- `gpuMode` 当前正式值不包含 `auto`

---

## 3. 改哪里

| 目标 | 文件路径 |
|------|----------|
| 某台机器参数 | `nix/hosts/<platform>/<host>/vars.nix` |
| 系统服务/内核/持久化 | `nix/modules/core/`（入口 `default.nix`） |
| 角色逻辑 | `nix/lib/host-meta.nix`（roleFlags）+ `nix/modules/core/roles/*.nix` |
| 硬件/显卡 | `nix/modules/core/hardware.nix` + `nix/lib/default.nix` + `nix/hosts/nixos/<host>/hardware*.nix` + `nix/hosts/nixos/_shared/` |
| 用户软件包 / 主账号开发环境 | `nix/home/linux/packages.nix` |
| 桌面服务 | `nix/home/linux/desktop.nix` |
| 程序配置 | `nix/home/linux/programs.nix` |
| XDG/portal | `nix/home/linux/xdg.nix` |
| 跨平台共享 | `nix/home/base/default.nix` |
| macOS 配置 | `nix/home/darwin/default.nix` |
| 密钥管理 | `nix/scripts/admin/sops.sh` |
| 安装流程 | `nix/scripts/admin/install-live.sh` |
| `flake.lock` 更新 | `nix/scripts/admin/update-flake.sh` |
| 主机 registry / metadata | `nix/hosts/registry/systems.toml` + `nix/hosts/outputs/` |
| 新增主机参考 | `nix/hosts/README.md` |

---

## 4. 常用命令

```bash
just host=zly disk=/dev/nvme0n1 install
just update
just info
just host=zly check
just host=zly switch
just clean
just sops-init-create
just guard-secrets
```

补充：当前仓库已不再保留 `repo-check` / `flake-check` / `eval-tests` / `deploy` 包装层；常用 `build` / `check` / `switch` / `test` / `clean` 入口通过 `just` 暴露。
补充：read-only flake eval/build/check 需要先走 `print-flake-repo.sh`，避免 `.keys/main.agekey` 不可读时直接访问原始 `path:` flake。
补充：显式传入的 `--repo` / `NIXOS_CONFIG_REPO` 必须有效；脚本不会静默回退到当前 checkout。
补充：`sops.sh` / `guard-secrets.sh` 可以从仓库外直接调用。

---

## 5. 提交规则

- Conventional Commit（`feat:`、`fix:`、`docs:`、`refactor:`）
- 每次提交只做一个主题
- 用户要求同步时执行 `git push origin HEAD`

---

## 6. 安全红线

详见 `CLAUDE.md` §4。核心：不提交私钥，`secrets/*.yaml` 可提交，`.keys/*.agekey` 不可提交。

---

## 7. 变更原则

- 最小改动优先，不做无关重构
- 先保证正确性，再考虑可维护性
- 有现成模式就复用
