# AGENTS.md（新手协作版）

本文件面向人类贡献者与自动化代理。
目标：让第一次接触本仓库的人，也能安全地改动并验证。

---

## 1. 先知道这是什么仓库

这是一个 flake-based 多主机配置仓库：
- NixOS 主机：`hosts/nixos/<host>/`
- macOS 主机：`hosts/darwin/<host>/`
- 聚合输出：`hosts/outputs/`
- 共享系统模块：`nix/modules/`
- 共享 Home Manager：`nix/home/`

---

## 2. 第一次贡献前，先跑这几个命令

```bash
just hosts
just eval-tests
just flake-check
```

如果你改了 Nix 文件，再补：

```bash
just fmt
just lint
```

---

## 3. 常用命令（优先记这几个）

```bash
just check
just test
just switch
just darwin-check
just darwin-switch
```

新增主机：

```bash
just new-nixos-host <name>
just new-darwin-host <name>
```

---

## 4. 目录改动指引（改哪里）

- 改某一台机器参数：`hosts/<platform>/<host>/vars.nix`
- 改系统行为（服务/内核/持久化）：`nix/modules/system/`（入口 `default.nix`）
- 改角色逻辑（哪些功能按角色启用）：`lib/default.nix` 中的 `roleFlags` + `nix/modules/system/role-services.nix`
- 改硬件与显卡：`nix/modules/hardware.nix`
- 改用户软件包：`nix/home/linux/packages.nix`
- 改桌面服务（waybar/swaybg/systemd user services）：`nix/home/linux/desktop.nix`
- 改程序配置（fzf/mpv/zsh/vim）：`nix/home/linux/programs.nix`
- 改 XDG（portal/mimeApps/configFile）：`nix/home/linux/xdg.nix`
- 改跨平台共享配置（session 变量/PATH）：`nix/home/base/default.nix`
- 改 macOS 用户配置：`nix/home/darwin/default.nix`
- 改密钥/密码管理：`scripts/agenix.sh`
- 改安装流程：`scripts/install-live.sh`
- 改主机发现或脚手架：`scripts/resolve-host.sh`、`scripts/new-host.sh`

---

## 5. 文档同步硬规则

详见 `CLAUDE.md` §3（必须保持的一致性）。

---

## 6. 提交规则

- 使用 Conventional Commit：`feat:`、`fix:`、`docs:`、`refactor:` 等
- 每次提交只做一个主题（例如“文档重写”不要混入系统逻辑变更）
- 用户要求同步 GitHub 时，执行 `git push origin HEAD`

---

## 7. 安全红线（必须遵守）

详见 `CLAUDE.md` §4（安全规则）。

---

## 8. 变更原则

- 最小改动优先，不做无关重构
- 先保证正确性，再考虑性能与可维护性
- 有现成模式就复用，不重复造轮子

