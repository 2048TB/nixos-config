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
└── scripts/       # Shell 脚本（admin/）
```

其他顶层目录：`secrets/`、`wallpapers/`、`docs/`

---

## 2. 贡献前先验证

```bash
just hosts          # 确认主机列表
just eval-tests     # eval 测试
just flake-check    # flake 完整检查
just repo-check     # 仓库级自检（脚本 + eval + flake）
```

改了 Nix 文件再补：`just fmt && just lint`

---

## 3. 改哪里

| 目标 | 文件路径 |
|------|----------|
| 某台机器参数 | `nix/hosts/<platform>/<host>/vars.nix` |
| 系统服务/内核/持久化 | `nix/modules/core/`（入口 `default.nix`） |
| 角色逻辑 | `nix/lib/host-meta.nix`（roleFlags）+ `nix/modules/core/roles/*.nix` |
| 硬件/显卡 | `nix/modules/core/hardware.nix` + `nix/hosts/nixos/<host>/hardware*.nix` |
| 用户软件包 / 主账号开发环境 | `nix/home/linux/packages.nix` |
| 桌面服务 | `nix/home/linux/desktop.nix` |
| 程序配置 | `nix/home/linux/programs.nix` |
| XDG/portal | `nix/home/linux/xdg.nix` |
| 跨平台共享 | `nix/home/base/default.nix` |
| macOS 配置 | `nix/home/darwin/default.nix` |
| 密钥管理 | `nix/scripts/admin/sops.sh` |
| 安装流程 | `nix/scripts/admin/install-live.sh` |
| 仓库级检查 | `nix/scripts/admin/repo-check.sh` |
| 新增主机参考 | `nix/hosts/README.md` |

---

## 4. 常用命令

```bash
just host=zly check && just host=zly switch   # 日常更新（建议显式 host）
just darwin-switch                             # macOS
```

注意：当前 `justfile` 默认 `host := ""`、`darwin_host := ""`。`just switch/check/test` 与 `just darwin-switch/darwin-check` 未显式指定时都会自动解析当前主机；跨主机操作仍建议显式写 `host=...` / `darwin_host=...`。

补充：当前 Linux/macOS 主账号的一致开发环境默认由 Home Manager 提供；system layer 仅保留桌面运行基线与系统服务。

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
