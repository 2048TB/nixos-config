# AGENTS.md

面向人类贡献者与自动化代理。目标：安全地改动并验证。

---

## 1. 仓库概览

flake-based 多主机配置仓库，所有 Nix/脚本代码在 `nix/` 下：

```text
nix/
├── lib/           # Nix 库函数
├── hosts/         # 主机配置（nixos/ + darwin/ + outputs/）
├── modules/       # 系统模块（core/ + darwin/）
├── home/          # Home Manager（base/ + linux/ + darwin/ + configs/）
└── scripts/       # Shell 脚本（admin/ + checks/ + tests/）
```

其他顶层目录：`secrets/`、`wallpapers/`、`docs/`、`.github/`

---

## 2. 贡献前先验证

```bash
just hosts          # 确认主机列表
just eval-tests     # eval 测试
just flake-check    # flake 完整检查
just repo-check     # 仓库级自检（shell syntax + tests + registry + eval + flake）
```

改了 Nix 文件再补：`just fmt && just lint`

---

## 3. Host Metadata 模型

- host metadata 事实源：`nix/hosts/registry/systems.toml`
- registry 当前字段：`system`、`kind`、`formFactor`、`desktopSession`、`desktopProfile`、`tags`、`gpuVendors`、`displays`、deploy 元数据
- 模块消费路径：`registry -> my.host -> my.capabilities`
- Linux NixOS/Home Manager 入口默认走 auto-discovered `_mixins`
- `roles` 是功能开关；不要重新引入旧 `profiles` 模型，也不要把 machine topology 塞进 `roles`
- `tags` 只保留无法稳定派生的事实；`multi-monitor` / `hidpi` 这类 display facts 不再手写
- 不要在桌面配置里硬编码 monitor 名称；优先从 registry `displays` metadata 生成
- Linux `desktopProfile` 当前只支持 `niri`；Darwin 使用 `aqua`
- `gpuMode` 当前正式值不包含 `auto`

---

## 4. 改哪里

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
| 仓库级检查 | `nix/scripts/admin/repo-check.sh` |
| registry / input 审计 | `nix/scripts/checks/*.sh` |
| 新增主机参考 | `nix/hosts/README.md` |

---

## 5. 常用命令

```bash
just host=zly check && just host=zly switch   # 日常更新（建议显式 host）
just darwin-switch                             # macOS
```

注意：当前 `justfile` 默认 `host := ""`、`darwin_host := ""`。`just switch/check/test` 与 `just darwin-switch/darwin-check` 未显式指定时都会自动解析当前主机；跨主机操作仍建议显式写 `host=...` / `darwin_host=...`。

补充：当前 Linux/macOS 主账号的一致开发环境默认由 Home Manager 提供；system layer 仅保留桌面运行基线与系统服务。
补充：当前 NixOS 主机默认直接复用 `nix/hosts/nixos/_shared/hardware-workarounds-common.nix`；只有出现主机专属硬件问题时才再创建本地 `hardware-workarounds.nix`。
补充：`repo-check` 会覆盖 `nix/scripts/admin/*.sh`、`nix/scripts/checks/*.sh`、`nix/scripts/tests/*.sh` 的 shell 语法检查。
补充：read-only flake eval/build/check 优先走 `just` 或仓库脚本；当前脚本会在 `.keys/main.agekey` 不可读时自动切到 filtered flake repo。

---

## 6. 提交规则

- Conventional Commit（`feat:`、`fix:`、`docs:`、`refactor:`）
- 每次提交只做一个主题
- 用户要求同步时执行 `git push origin HEAD`

---

## 7. 安全红线

详见 `CLAUDE.md` §4。核心：不提交私钥，`secrets/*.yaml` 可提交，`.keys/*.agekey` 不可提交。

---

## 8. 变更原则

- 最小改动优先，不做无关重构
- 先保证正确性，再考虑可维护性
- 有现成模式就复用
