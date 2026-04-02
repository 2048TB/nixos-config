# Linux Home Manager Mixins

本目录的 `default.nix` 维护 Linux Home Manager self-gating 模块的显式 allowlist。

约束：

- `default.nix` 自身不参与导入
- `package-groups.nix` 是数据文件，不参与 allowlist
- root 目录下新增 `.nix` 文件不会自动导入
- 只有 allowlist 中的模块会加载
