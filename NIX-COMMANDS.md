# Nix 常用命令速查

本文档包含 NixOS 和 Nix Flakes 的常用命令。

---

## 系统管理

### 重建系统

```bash
# 应用配置并立即切换（推荐）
sudo nixos-rebuild switch --flake .#nixos-cconfig

# 应用配置但下次启动生效
sudo nixos-rebuild boot --flake .#nixos-cconfig

# 临时测试配置（重启后失效）
sudo nixos-rebuild test --flake .#nixos-cconfig

# 检查配置语法但不应用
sudo nixos-rebuild dry-build --flake .#nixos-cconfig

# 显示详细构建日志（使用 nom 美化输出）
sudo nixos-rebuild switch --flake .#nixos-cconfig |& nom

# 使用环境变量覆盖配置（需要 --impure）
NIXOS_GPU=amd sudo nixos-rebuild switch --impure --flake .#nixos-cconfig
```

### 系统世代管理

```bash
# 列出所有系统世代
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# 回滚到上一个世代
sudo nixos-rebuild switch --rollback

# 删除旧世代（保留最近 3 个）
sudo nix-collect-garbage --delete-older-than 3d

# 删除所有旧世代（仅保留当前）
sudo nix-collect-garbage -d

# 优化存储（硬链接重复文件）
sudo nix-store --optimise
```

### 查看系统信息

```bash
# 查看当前系统配置
nixos-version

# 查看系统启动世代列表
sudo nix-env -p /nix/var/nix/profiles/system --list-generations

# 查看当前世代
readlink /run/current-system

# 对比两个世代的差异
nix store diff-closures /nix/var/nix/profiles/system-{旧版本号,新版本号}-link
```

---

## Flake 操作

### 基础命令

```bash
# 更新 flake.lock（更新所有输入）
nix flake update

# 只更新特定输入
nix flake lock --update-input nixpkgs

# 查看 flake 元数据
nix flake metadata

# 查看 flake 输出
nix flake show

# 检查 flake 配置
nix flake check

# 查看 flake.lock 依赖树
nix-melt
```

### Flake 模板

```bash
# 列出可用模板
nix flake show templates

# 初始化新项目
nix flake init -t templates#<模板名>
```

---

## 包管理

### 搜索和查询

```bash
# 搜索包
nix search nixpkgs <包名>

# 搜索包（使用正则）
nix search nixpkgs '.*python.*'

# 查看包详细信息
nix-env -qa --description '.*包名.*'

# 查看包的所有版本
nix search nixpkgs --json <包名> | jq

# 查看包的依赖树
nix-tree /run/current-system

# 查看包的逆向依赖
nix-store --query --referrers /nix/store/<包路径>
```

### 临时使用包

```bash
# 临时运行某个包的程序（不安装）
nix run nixpkgs#<包名>

# 创建包含特定包的 shell 环境
nix shell nixpkgs#<包名1> nixpkgs#<包名2>

# 进入开发环境（使用 flake.nix 定义的 devShell）
nix develop

# 使用特定包运行命令
nix run nixpkgs#hello -- --version
```

### 用户环境包管理

```bash
# 安装包到用户环境（不推荐，建议用 Home Manager）
nix-env -iA nixpkgs.<包名>

# 卸载包
nix-env -e <包名>

# 列出已安装的包
nix-env -q

# 升级所有包
nix-env -u
```

---

## 开发和构建

### 构建操作

```bash
# 构建 flake 输出
nix build .#<输出名>

# 构建并查看结果
nix build .#<输出名> && ls -la result/

# 构建 ISO
nix build .#nixos-cconfig-iso

# 构建并复制到当前目录
nix build .#<输出名> --out-link ./my-result
```

### 开发环境

```bash
# 进入开发 shell
nix develop

# 运行开发 shell 中的命令
nix develop -c <命令>

# 使用特定 shell
nix develop --command zsh
```

### 代码质量工具

```bash
# 格式化 Nix 代码
nixpkgs-fmt .

# 静态检查
statix check .

# 查找死代码（未使用的变量）
deadnix .

# 自动修复（谨慎使用）
statix fix .
```

---

## Binary Cache 和性能

### 查看缓存状态

```bash
# 查看包是否有缓存
nix path-info --store https://cache.nixos.org /nix/store/<包路径>

# 查看所有替代源
nix show-config | grep substituters

# 测试替代源可用性
nix path-info --store https://nix-community.cachix.org nixpkgs#hello
```

### 使用 Cachix

```bash
# 添加 cachix 缓存（一次性）
cachix use nix-community

# 推送到自己的 cachix
nix build .#<输出名>
cachix push <your-cache> ./result

# 查看 cachix 配置
cachix list
```

### 强制使用缓存

```bash
# 优先从缓存下载，拒绝本地编译
nix build --option substitute true --option builders ""

# 查看构建日志（判断是否在本地编译）
nix log /nix/store/<包路径>
```

---

## 存储管理

### 查看存储使用

```bash
# 查看 Nix store 大小
du -sh /nix/store

# 查看哪些包占用最多空间
nix path-info -rsSh /run/current-system | sort -hk2 | tail -20

# 查看包的依赖大小
nix path-info -rsh nixpkgs#<包名>
```

### 垃圾回收

```bash
# 列出可以清理的垃圾
nix-store --gc --print-dead

# 删除所有未引用的包
nix-collect-garbage

# 删除超过 N 天的旧世代
sudo nix-collect-garbage --delete-older-than 7d

# 完整清理（包括当前世代外的所有内容）
sudo nix-collect-garbage -d

# 优化存储（查找并硬链接重复文件）
sudo nix-store --optimise

# 验证存储完整性
sudo nix-store --verify --check-contents
```

---

## Home Manager

### 基础操作

```bash
# 应用 Home Manager 配置
home-manager switch --flake .#<用户名>

# 查看 Home Manager 世代
home-manager generations

# 回滚到上一个世代
home-manager switch --rollback

# 删除旧世代
home-manager expire-generations "-7 days"
```

### 查询配置

```bash
# 查看当前配置
home-manager packages

# 列出已安装的包
nix-env -q --installed
```

---

## 调试和故障排查

### 查看日志

```bash
# 查看系统服务日志
journalctl -u <服务名>

# 查看用户服务日志
journalctl --user -u <服务名>

# 查看构建日志
nix log /nix/store/<包路径>

# 实时查看日志
journalctl -f
```

### 调试构建

```bash
# 显示构建详细信息
nix build --print-build-logs .#<输出名>

# 保留失败的构建目录
nix build --keep-failed .#<输出名>

# 进入失败构建的环境
nix develop /tmp/nix-build-<包名>.drv-0

# 查看包的构建推导
nix show-derivation nixpkgs#<包名>
```

### 测试配置

```bash
# 检查配置语法
nix flake check

# 评估配置表达式
nix eval .#nixosConfigurations.nixos-cconfig.config.networking.hostName

# 查看完整配置选项
nix repl
> :lf .
> nixosConfigurations.nixos-cconfig.config.system.build.toplevel
```

---

## 网络和下载

### 代理设置

```bash
# 使用代理构建
https_proxy=http://127.0.0.1:7890 nix build .#<输出名>

# 设置 Nix 代理（全局）
sudo vim /etc/nix/nix.conf
# 添加：
# proxy = http://127.0.0.1:7890
```

### 下载和哈希

```bash
# 预取 URL 并计算哈希
nix-prefetch-url <URL>

# 预取 Git 仓库
nix-prefetch-git <URL>

# 计算文件哈希
nix hash file <文件路径>

# 计算目录哈希
nix hash path <目录路径>
```

---

## 远程构建

### SSH 远程构建

```bash
# 配置远程构建机（/etc/nix/machines）
# <主机> <系统> <SSH密钥> <最大任务数> <速度因子> <支持的特性> <必需的特性>
# builder@remote x86_64-linux /root/.ssh/id_ed25519 4 2 kvm,nixos-test benchmark

# 使用远程构建
nix build --builders 'ssh://builder@remote' .#<输出名>
```

---

## 实用技巧

### 性能优化

```bash
# 使用多核编译
nix build --cores 0  # 使用所有核心
nix build --cores 4  # 使用 4 核心

# 并行构建多个包
nix build --max-jobs auto
```

### 快速查找包

```bash
# 使用 nix-index 快速查找命令所属包
nix-locate bin/hello

# 构建索引数据库
nix-index
```

### 比较配置

```bash
# 比较两次系统构建的差异
nix store diff-closures \
  /nix/var/nix/profiles/system-150-link \
  /nix/var/nix/profiles/system-151-link
```

---

## 常见问题解决

### 清理磁盘空间不足

```bash
# 1. 删除旧世代
sudo nix-collect-garbage --delete-older-than 7d

# 2. 优化存储
sudo nix-store --optimise

# 3. 删除构建缓存
sudo rm -rf /tmp/nix-build-*
```

### 修复损坏的包

```bash
# 修复单个包
nix-store --repair-path /nix/store/<包路径>

# 验证所有包
sudo nix-store --verify --check-contents --repair
```

### 清除 Nix 锁

```bash
# 删除锁文件（如果构建异常中断）
sudo rm /nix/var/nix/db/big-lock
sudo rm /nix/var/nix/gc.lock
```

---

## 配置文件位置

| 文件 | 路径 | 说明 |
|------|------|------|
| Nix 配置 | `/etc/nix/nix.conf` | 全局 Nix 配置 |
| Flake 锁 | `flake.lock` | 依赖版本锁定 |
| 系统配置 | `/etc/nixos/` | 传统配置目录（使用 Flake 时可忽略） |
| 用户配置 | `~/.config/nix/` | 用户级别 Nix 配置 |
| Store 路径 | `/nix/store/` | 包存储位置 |

---

## 推荐工作流

### 日常配置修改

```bash
# 1. 修改配置文件
vim home/core/default.nix

# 2. 检查语法
nix flake check

# 3. 测试构建（不应用）
sudo nixos-rebuild dry-build --flake .#nixos-cconfig

# 4. 应用配置
sudo nixos-rebuild switch --flake .#nixos-cconfig |& nom

# 5. 提交更改
git add .
git commit -m "feat: 添加新软件包"
git push
```

### 清理维护

```bash
# 每周运行一次
sudo nix-collect-garbage --delete-older-than 7d
sudo nix-store --optimise

# 每月运行一次
nix flake update
sudo nixos-rebuild switch --flake .#nixos-cconfig
```

---

## 参考资源

- [Nix 官方文档](https://nixos.org/manual/nix/stable/)
- [NixOS 手册](https://nixos.org/manual/nixos/stable/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [Home Manager 手册](https://nix-community.github.io/home-manager/)
- [Nix.dev 教程](https://nix.dev/)
