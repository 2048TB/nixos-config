# Justfile for NixOS Configuration Management
# 使用 `just` 查看所有命令，`just <命令>` 执行命令

# 默认显示帮助
default:
    @just --list

host := "zzly"
darwin_host := ""
disk := "/dev/nvme0n1"
repo := env_var_or_default("NIXOS_CONFIG_REPO", justfile_directory())
key_dir_rel := ".keys"
age_key_rel := "{{key_dir_rel}}/main.agekey"

# ========== 系统管理 ==========

# 安装前构建校验（不落盘；需指定 host）
install-check:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=zly install-check" >&2; exit 2; fi
    nix build --no-link .#nixosConfigurations.{{host}}.config.system.build.toplevel

# 一键安装（危险：会清空 {{disk}}；需指定 host）
install:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=zly disk=/dev/nvme0n1 install" >&2; exit 2; fi
    {{repo}}/nix/scripts/admin/install-live.sh --host {{host}} --disk {{disk}} --repo {{repo}}

# 应用配置并立即切换（不指定 host 则自动检测当前主机）
switch:
    h="{{host}}"; if [ -z "$h" ]; then h="$({{repo}}/nix/scripts/admin/resolve-host.sh nixos {{repo}} auto --strict)"; fi; echo ">>> host=$h"; sudo nixos-rebuild switch --flake "path:{{repo}}#$h" |& nom

# 应用配置但下次启动生效
boot:
    h="{{host}}"; if [ -z "$h" ]; then h="$({{repo}}/nix/scripts/admin/resolve-host.sh nixos {{repo}} auto --strict)"; fi; echo ">>> host=$h"; sudo nixos-rebuild boot --flake "path:{{repo}}#$h" |& nom

# 临时测试配置（重启后失效）
test:
    h="{{host}}"; if [ -z "$h" ]; then h="$({{repo}}/nix/scripts/admin/resolve-host.sh nixos {{repo}} auto --strict)"; fi; echo ">>> host=$h"; sudo nixos-rebuild test --flake "path:{{repo}}#$h" |& nom

# 检查配置但不应用（快速验证）
check:
    h="{{host}}"; if [ -z "$h" ]; then h="$({{repo}}/nix/scripts/admin/resolve-host.sh nixos {{repo}} auto --strict)"; fi; echo ">>> host=$h"; nix build --no-link "path:{{repo}}#nixosConfigurations.$h.config.system.build.toplevel"

# 快速执行 eval tests（hostname/home 映射一致性）
eval-tests:
    @echo "=== checks.x86_64-linux (eval tests) ==="
    nix build --no-link \
      path:{{repo}}#checks.x86_64-linux.evaltest-hostname \
      path:{{repo}}#checks.x86_64-linux.evaltest-home \
      path:{{repo}}#checks.x86_64-linux.evaltest-kernel \
      path:{{repo}}#checks.x86_64-linux.evaltest-platform
    @echo ""
    @echo "=== checks.aarch64-darwin (eval only) ==="
    nix eval path:{{repo}}#checks.aarch64-darwin.evaltest-darwin-hostname.drvPath >/dev/null
    nix eval path:{{repo}}#checks.aarch64-darwin.evaltest-darwin-home.drvPath >/dev/null
    nix eval path:{{repo}}#checks.aarch64-darwin.evaltest-darwin-platform.drvPath >/dev/null

# 回滚到上一个系统世代
rollback:
    sudo nixos-rebuild switch --rollback

# ========== Darwin 管理 ==========

# 应用 macOS 配置（不指定 darwin_host 则自动检测）
darwin-switch:
    h="{{darwin_host}}"; if [ -z "$h" ]; then h="$({{repo}}/nix/scripts/admin/resolve-host.sh darwin {{repo}} auto --strict)"; fi; echo ">>> darwin_host=$h"; darwin-rebuild switch --flake "path:{{repo}}#$h"

# 构建 macOS 配置（不切换）
darwin-check:
    h="{{darwin_host}}"; if [ -z "$h" ]; then h="$({{repo}}/nix/scripts/admin/resolve-host.sh darwin {{repo}} auto --strict)"; fi; echo ">>> darwin_host=$h"; nix build --no-link "path:{{repo}}#darwinConfigurations.$h.system"

# 列出可用 darwin 主机
darwin-hosts:
    nix eval path:{{repo}}#darwinConfigurations --apply builtins.attrNames

# 列出可用 nixos 主机
nixos-hosts:
    nix eval path:{{repo}}#nixosConfigurations --apply builtins.attrNames

# 列出全部主机
hosts:
    @echo "=== nixosConfigurations ==="
    @just nixos-hosts
    @echo ""
    @echo "=== darwinConfigurations ==="
    @just darwin-hosts

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
    nix flake update --flake path:{{repo}}
    @echo "✓ flake.lock 已更新"

# 只更新 nixpkgs
update-nixpkgs:
    nix flake update nixpkgs --flake path:{{repo}}
    @echo "✓ nixpkgs 已更新"

# 查看 flake 信息
info:
    nix flake show path:{{repo}}
    @echo ""
    @echo "=== Flake 元数据 ==="
    nix flake metadata path:{{repo}}

# 检查 flake 配置
flake-check:
    nix flake check --all-systems path:{{repo}}
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
    h="{{host}}"; if [ -z "$h" ]; then h="$({{repo}}/nix/scripts/admin/resolve-host.sh nixos {{repo}} auto --strict)"; fi; \
    echo "=== declared environment.systemPackages (host=$h) ==="; \
    nix eval --raw "path:{{repo}}#nixosConfigurations.$h.config.environment.systemPackages" --apply 'pkgs: builtins.concatStringsSep "\n" (map (p: (builtins.parseDrvName p.name).name) pkgs)' | awk 'NF && !seen[$0]++'; \
    echo ""; \
    u="$(nix eval --raw "path:{{repo}}#nixosConfigurations.$h.config.home-manager.users" --apply 'users: builtins.head (builtins.attrNames users)')"; \
    echo "=== declared home.packages (host=$h user=$u) ==="; \
    nix eval --raw "path:{{repo}}#nixosConfigurations.$h.config.home-manager.users.$u.home.packages" --apply 'pkgs: builtins.concatStringsSep "\n" (map (p: (builtins.parseDrvName p.name).name) pkgs)' | awk 'NF && !seen[$0]++'

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

# 启用仓库内 git hooks（pre-commit）
hooks-enable:
    git config core.hooksPath .githooks
    @echo "✓ 已启用 .githooks"

# 密钥泄露保护（阻止提交/推送敏感文件）
guard-secrets:
    @{{repo}}/nix/scripts/admin/guard-secrets.sh

# 初始化 sops 主密钥（默认只同步，不自动创建）
sops-init:
    @{{repo}}/nix/scripts/admin/sops.sh init

# 首次初始化 sops 主密钥（仅在 main.agekey 缺失时创建）
sops-init-create:
    @{{repo}}/nix/scripts/admin/sops.sh init --create

# 旋转 sops 主密钥（危险：需要立即 rekey）
sops-init-rotate:
    @{{repo}}/nix/scripts/admin/sops.sh init --rotate

# 初始化/更新恢复密钥（本地 .keys/recovery.agekey + 仓库公钥）
sops-recovery-init:
    @{{repo}}/nix/scripts/admin/sops.sh recovery-init

# 添加主机 SSH host 公钥 recipient（默认读取 /etc/ssh/ssh_host_ed25519_key.pub）
sops-host-key-add HOST PUB="/etc/ssh/ssh_host_ed25519_key.pub":
    @{{repo}}/nix/scripts/admin/sops.sh host-add '{{HOST}}' '{{PUB}}'

# 列出 sops recipients
sops-recipients:
    @{{repo}}/nix/scripts/admin/sops.sh recipients

# 按当前 recipients 重加密所有 secrets/*.yaml
sops-rekey:
    @{{repo}}/nix/scripts/admin/sops.sh rekey

# 生成 sha-512 密码哈希（交互输入密码）
password-hash:
    if command -v mkpasswd >/dev/null 2>&1; then \
      mkpasswd -m sha-512; \
    else \
      nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512; \
    fi

# 连续生成用户与 root 的密码哈希
password-hashes:
    @echo ">>> userPasswordHash"
    @just password-hash
    @echo ""
    @echo ">>> rootPasswordHash"
    @just password-hash

# 将同一个密码哈希写入 sops（user/root）
password-set-hash HASH:
    @{{repo}}/nix/scripts/admin/sops.sh password-set '{{HASH}}'

# 将 .keys/github_id_ed25519(.pub) 加密写入 sops secrets
ssh-key-set:
    @{{repo}}/nix/scripts/admin/sops.sh ssh-key-set

# 提交所有更改
commit MESSAGE:
    git add .
    @just guard-secrets
    git commit -m "{{MESSAGE}}"
    @echo "✓ 已提交：{{MESSAGE}}"

# 提交并推送
push MESSAGE:
    git add .
    @just guard-secrets
    git commit -m "{{MESSAGE}}"
    git push origin HEAD
    @echo "✓ 已推送到 GitHub（当前分支）"

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
    @echo "tip: 使用 'just commit \"消息\"' 提交更改"

# ========== 构建和安装 ==========

# 进入开发环境
shell:
    nix develop

# ========== 文档查看 ==========

# 查看快捷键文档
keys:
    @bat --style=plain docs/KEYBINDINGS.md || cat docs/KEYBINDINGS.md

# 查看 Nix 命令文档
commands:
    @bat --style=plain docs/NIX-COMMANDS.md || cat docs/NIX-COMMANDS.md

# 查看所有文档
docs:
    @echo "=== 可用文档 ==="
    @echo "docs/README.md            - 主文档（含 Binary Cache 说明）"
    @echo "docs/KEYBINDINGS.md       - 快捷键说明"
    @echo "docs/NIX-COMMANDS.md      - Nix 命令速查"
    @echo "docs/ENV-USAGE.md         - 多环境使用手册"

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
    @echo "常用命令快速参考"
    @echo ""
    @echo "[安装] Live ISO（需指定 host）："
    @echo "  just host=zly install-check"
    @echo "  just host=zly disk=/dev/nvme0n1 install"
    @echo ""
    @echo "[日常]（自动检测主机，或 just host=xxx 指定）："
    @echo "  just switch      - 应用配置"
    @echo "  just boot        - 下次启动生效"
    @echo "  just quick       - 检查 + 应用"
    @echo "  just clean       - 清理旧世代"
    @echo ""
    @echo "[更新]："
    @echo "  just upgrade     - 更新并应用"
    @echo "  just update      - 只更新 flake.lock"
    @echo ""
    @echo "[Git]："
    @echo "  just status      - 查看状态"
    @echo "  just push \"消息\" - 提交并推送"
    @echo ""
    @echo "[文档]："
    @echo "  just keys        - 快捷键说明"
    @echo "  just commands    - Nix 命令"
    @echo ""
    @echo "tip: 使用 'just' 查看所有命令"
