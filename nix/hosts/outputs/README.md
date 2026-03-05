# outputs 目录

将所有主机汇总为 flake outputs。

---

## 文件

- `default.nix` — 总入口（genSpecialArgs、mkApp）
- `x86_64-linux/default.nix` — NixOS 聚合 + eval tests + apps
- `aarch64-darwin/default.nix` — Darwin 聚合 + eval tests + apps
- `*/tests/` — 评估测试（hostname/home/kernel/platform）

---

## 自动发现

聚合层自动扫描 `nix/hosts/nixos/*` 和 `nix/hosts/darwin/*`，主机目录里必需文件齐全即可被发现。

```bash
just hosts   # 查看已注册主机
```

通常无需手动修改此目录，除非新增平台级逻辑（apps/checks/devShell）。
