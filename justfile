# Justfile for NixOS Configuration Management
# 使用 `just` 查看所有命令，`just <命令>` 执行命令

# 默认显示帮助
default:
    @just --list

# ========== 系统管理 ==========

# 应用配置并立即切换（常用）
switch:
    sudo nixos-rebuild switch --flake /etc/nixos#zly |& nom

# 应用配置但下次启动生效
boot:
    sudo nixos-rebuild boot --flake /etc/nixos#zly |& nom

# 临时测试配置（重启后失效）
test:
    sudo nixos-rebuild test --flake /etc/nixos#zly |& nom

# 检查配置但不应用（快速验证）
check:
    sudo nixos-rebuild dry-build --flake /etc/nixos#zly

# 回滚到上一个系统世代
rollback:
    sudo nixos-rebuild switch --rollback

# ========== 清理维护 ==========

# 删除 7 天前的旧世代
clean:
    sudo nix-collect-garbage --delete-older-than 7d
    @echo "✓ 已清理 7 天前的旧世代"

# 完全清理（仅保留当前世代）
clean-all:
    sudo nix-collect-garbage -d
    @echo "✓ 已删除所有旧世代"

# 优化存储（硬链接重复文件）
optimize:
    sudo nix-store --optimise
    @echo "✓ 存储优化完成"

# 完整清理和优化
clean-optimize: clean optimize
    @echo "✓ 清理和优化完成"

# 查看存储使用情况
disk:
    @echo "=== Nix Store 总大小 ==="
    @du -sh /nix/store
    @echo ""
    @echo "=== 占用空间最大的 20 个包 ==="
    @nix path-info -rsSh /run/current-system | sort -hk2 | tail -20

# ========== Flake 操作 ==========

# 更新所有 flake 输入
update:
    nix flake update --flake path:/persistent/nixos-config
    @echo "✓ flake.lock 已更新"

# 只更新 nixpkgs
update-nixpkgs:
    nix flake update nixpkgs --flake path:/persistent/nixos-config
    @echo "✓ nixpkgs 已更新"

# 查看 flake 信息
info:
    nix flake show path:/persistent/nixos-config
    @echo ""
    @echo "=== Flake 元数据 ==="
    nix flake metadata path:/persistent/nixos-config

# 检查 flake 配置
flake-check:
    nix flake check path:/persistent/nixos-config
    @echo "✓ Flake 配置检查通过"

# 查看 flake.lock 依赖树
lock:
    nix-melt

# ========== 代码质量 ==========

# 格式化所有 Nix 代码
fmt:
    nixpkgs-fmt .
    @echo "✓ 代码格式化完成"

# 静态检查
lint:
    statix check .
    @echo "✓ 静态检查通过"

# 查找死代码
dead:
    deadnix .

# 自动修复静态检查问题（谨慎使用）
fix:
    statix fix .
    @echo "✓ 自动修复完成"

# 完整代码检查（格式化 + 检查 + 死代码）
check-all: fmt lint dead
    @echo "✓ 完整代码检查完成"

# ========== 查看信息 ==========

# 列出所有系统世代
generations:
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# 对比最近两个世代的差异
diff:
    @bash -c 'gens=($(ls -d /nix/var/nix/profiles/system-*-link 2>/dev/null | sort -t- -k2 -n)); n=${#gens[@]}; if (( n < 2 )); then echo "Need at least 2 generations to diff"; exit 1; fi; nix store diff-closures "${gens[$((n-2))]}" "${gens[$((n-1))]}"'

# 查看当前系统包列表
packages:
    nix-env -q --installed

# 查看包依赖树（需要先 switch）
tree:
    nix-tree /run/current-system

# 查看系统版本信息
version:
    @echo "=== NixOS 版本 ==="
    @nixos-version
    @echo ""
    @echo "=== 当前配置路径 ==="
    @readlink /run/current-system

# ========== Git 操作 ==========

# 查看 git 状态
status:
    @git status

# 提交所有更改
commit MESSAGE:
    git add .
    git commit -m "{{MESSAGE}}"
    @echo "✓ 已提交：{{MESSAGE}}"

# 提交并推送
push MESSAGE:
    git add .
    git commit -m "{{MESSAGE}}" -m "Co-Authored-By: Claude Sonnet 4.5 (1M context) <noreply@anthropic.com>"
    git push origin main
    @echo "✓ 已推送到 GitHub"

# 拉取最新配置
pull:
    git pull
    @echo "✓ 已拉取最新配置"

# 查看最近的提交
log:
    @git log --oneline -10

# ========== 快速工作流 ==========

# 快速应用配置（检查 + 应用）
quick: check switch
    @echo "✓ 配置已应用"

# 完整工作流（检查 + 应用 + 清理）
full: check-all switch clean
    @echo "✓ 完整流程执行完成"

# 更新并应用配置
upgrade: update switch
    @echo "✓ 系统已升级到最新版本"

# 开发流程（格式化 + 检查 + 测试 + 提示提交）
dev: fmt flake-check test
    @echo ""
    @echo "✓ 开发检查完成"
    @echo "💡 使用 'just commit \"消息\"' 提交更改"

# ========== 构建和安装 ==========

# 构建 ISO 镜像
# 进入开发环境
shell:
    nix develop

# ========== 文档查看 ==========

# 查看快捷键文档
keys:
    @bat --style=plain KEYBINDINGS.md || cat KEYBINDINGS.md

# 查看 Nix 命令文档
commands:
    @bat --style=plain NIX-COMMANDS.md || cat NIX-COMMANDS.md

# 查看优化文档
perf:
    @bat --style=plain .github-optimization.md || cat .github-optimization.md

# 查看所有文档
docs:
    @echo "=== 可用文档 ==="
    @echo "README.md            - 主文档"
    @echo "KEYBINDINGS.md       - 快捷键说明"
    @echo "NIX-COMMANDS.md      - Nix 命令速查"
    @echo ".github-optimization.md - Binary Cache 优化"

# ========== 故障排查 ==========

# 验证 Nix store 完整性
verify:
    sudo nix-store --verify --check-contents
    @echo "✓ 存储验证完成"

# 修复损坏的包
repair PATH:
    sudo nix-store --repair-path {{PATH}}

# 查看系统日志（最近 50 行）
logs:
    journalctl -xe -n 50

# 查看 Nix 守护进程日志
nix-logs:
    journalctl -u nix-daemon -n 50

# ========== 实用工具 ==========

# 搜索包
search PACKAGE:
    nix search nixpkgs {{PACKAGE}}

# 查看包信息
package-info PACKAGE:
    nix-env -qa --description '.*{{PACKAGE}}.*'

# 临时运行包（不安装）
run PACKAGE:
    nix run nixpkgs#{{PACKAGE}}

# 创建包含指定包的临时环境
tmp PACKAGE:
    nix shell nixpkgs#{{PACKAGE}}

# ========== 帮助信息 ==========

# 显示常用命令
help:
    @echo "📖 常用命令快速参考"
    @echo ""
    @echo "🚀 日常使用："
    @echo "  just switch      - 应用配置"
    @echo "  just quick       - 检查 + 应用"
    @echo "  just clean       - 清理旧世代"
    @echo ""
    @echo "🔄 更新系统："
    @echo "  just upgrade     - 更新并应用"
    @echo "  just update      - 只更新 flake.lock"
    @echo ""
    @echo "📦 Git 操作："
    @echo "  just status      - 查看状态"
    @echo "  just push \"消息\" - 提交并推送"
    @echo ""
    @echo "📚 查看文档："
    @echo "  just keys        - 快捷键说明"
    @echo "  just commands    - Nix 命令"
    @echo ""
    @echo "💡 使用 'just' 查看所有命令"
