# hosts/outputs 说明（新手版）

这个目录负责把所有主机汇总成 flake outputs。

你可以理解为：
- `hosts/` 放“单机配置”
- `hosts/outputs/` 放“聚合与导出规则”

---

## 1. 关键文件

- `hosts/outputs/default.nix`：总入口
- `hosts/outputs/x86_64-linux/default.nix`：NixOS 聚合
- `hosts/outputs/aarch64-darwin/default.nix`：Darwin 聚合
- `hosts/outputs/*/tests/`：评估测试

---

## 2. 新增主机后为什么不用手工注册

因为聚合层会自动扫描：
- `hosts/nixos/*`
- `hosts/darwin/*`

只要主机目录里的“必需文件”齐全，就会自动出现在：

```bash
just hosts
```

---

## 3. 你通常不需要改这里

新手场景下，通常只改：
- `hosts/nixos/<host>/...`
- `hosts/darwin/<host>/...`

只有在你需要新增平台级逻辑（apps/checks/devShell）时，才改 `hosts/outputs/*`。

补充：
- `nix run .#build` / `.#build-switch` / `.#apply` 需要在仓库根目录执行；
- 或者设置 `NIXOS_CONFIG_REPO=<repo-root>` 后再执行。
- 以上命令的主机解析为 strict：仅接受环境变量或当前 hostname，不做 fallback。
