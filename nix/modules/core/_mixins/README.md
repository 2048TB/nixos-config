# Core Mixins

本目录的 `default.nix` 维护 `nix/modules/core/` self-gating 模块的显式 allowlist，并单独自动纳入 `roles/*.nix`。

约束：

- `options.nix` 是固定入口，不参与 `_mixins` allowlist
- `default.nix` 自身不参与导入
- root 目录下的 helper/data file 不会被隐式纳入
- 只有 allowlist 中的模块会加载
- `roles/*.nix` 自动纳入导入集
