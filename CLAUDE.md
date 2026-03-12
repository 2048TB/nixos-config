# CLAUDE.md

AI/自动化工具专用。目标：高效完成用户请求，不破坏仓库稳定性。

---

## 1. 工作边界

- 只做用户明确要求的改动，默认最小 diff
- 不做无关重构，中文说明，技术名词可用 English
- 优先复用现有脚本、模块和文档入口

---

## 2. 事实源与入口

- 运维主文档：`docs/README.md`
- 环境差异：`docs/ENV-USAGE.md`
- 命令速查：`docs/NIX-COMMANDS.md`
- 主机结构与 metadata：`nix/hosts/README.md`
- NixOS 主机模板：`nix/hosts/nixos/README.md`
- Home Manager 结构：`nix/home/README.md`
- secrets/public keys：`secrets/keys/README.md`
- 当前保留脚本：`nix/scripts/admin/{install-live,print-flake-repo,update-flake,sops,guard-secrets,common}.sh`
- 当前 CI：manual `flake.lock` freshness check + workflow run cleanup

---

## 3. 文档同步规则

| 改动范围 | 需同步的文档 |
|----------|-------------|
| 快捷键（Niri/Tmux/Zellij） | `docs/KEYBINDINGS.md` |
| 主机发现/脚手架/安装流程 | `README.md`、`docs/README.md`、`docs/NIX-COMMANDS.md`、`docs/ENV-USAGE.md` |
| hosts/hardware/disko/registry 布局 | `nix/hosts/README.md`、`nix/hosts/nixos/README.md`、必要时 `docs/ENV-USAGE.md` |
| justfile 命令或 flake apps | `docs/NIX-COMMANDS.md`、`docs/ENV-USAGE.md` |
| CI / workflow / 最小脚本入口 | `docs/README.md`、必要时 `CLAUDE.md` / `AGENTS.md` |
| 流程规则 | `CLAUDE.md`、`AGENTS.md` |

---

## 4. 安全规则

- 禁止提交私钥、token、明文密码
- `secrets/*.yaml` 可提交，`.keys/*.agekey` 不可提交
- 安装与分区（disko）命令视为危险操作
- 密码来源：sops（`secrets/passwords/*.yaml`），不使用明文文件
- `hosts/*.ssh_host_ed25519.pub` 若无效，`sops.sh recipients/rekey` 会直接失败

---

## 5. 验证要求

```bash
# 保留的 read-only 检查入口
just info
bash nix/scripts/admin/print-flake-repo.sh .

# 保留的脚本自检入口
bash -n nix/scripts/admin/*.sh
shellcheck nix/scripts/admin/*.sh
bash nix/scripts/admin/guard-secrets.sh
```

---

## 6. Host Metadata 约束

- host metadata 的事实源是 `nix/hosts/registry/systems.toml`
- registry 字段：`system`、`kind`、`formFactor`、`desktopSession`、`desktopProfile`、`tags`、`gpuVendors`、`displays`、deploy metadata
- 模块消费路径固定为：`registry -> my.host` typed options -> `my.capabilities`
- Linux NixOS/Home Manager 入口默认走 auto-discovered `_mixins`
- `roles` 仍保留为功能开关；不要重新引入旧 `profiles` host 模型，也不要把 machine topology 塞进 `roles`
- `tags` 只保留无法稳定派生的事实；`multi-monitor` / `hidpi` 这类 display facts 不再手写
- 不要在桌面配置里硬编码 monitor 名称；优先从 registry `displays` metadata 生成
- Linux `desktopProfile` 当前只支持 `niri`；Darwin 使用 `aqua`
- `gpuMode` 当前正式值为 `none` / `modesetting` / `amdgpu` / `nvidia` / `amd-nvidia-hybrid`，不要再写 `auto`

---

## 7. 执行提醒

- 当前 `justfile` 只保留最小入口；安装时必须显式指定 `host=...`
- 当前仓库仅保留 `nix/scripts/admin/*.sh`；不再保留 `repo-check`、`flake-check`、`eval-tests`、`rebuild-*`、`deploy` 包装层
- 对 read-only flake eval/build/check，优先走 `just` 或 `nix/scripts/admin/*.sh`；当前脚本会在 `.keys/main.agekey` 不可读时自动切到 filtered flake repo
- 显式传入的 `--repo` / `NIXOS_CONFIG_REPO` 必须有效；当前脚本不会再静默回退到脚本所在 checkout
- `sops.sh` / `guard-secrets.sh` 可从仓库外直接调用；脚本会自行定位 repo root
- 当前 CI 只保留 manual `flake.lock` 新鲜度检查与 workflow run 清理；不要把它描述成 push/PR 自动校验
- 未被要求时不主动推送；用户要求“同步到 GitHub”时才执行 Conventional Commit + `git push origin HEAD`
