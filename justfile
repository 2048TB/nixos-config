# Justfile for NixOS Configuration Management
# 使用 `just` 查看所有命令，`just <命令>` 执行命令

# 默认显示帮助
default:
    @just --list

host := "zly"
darwin_host := "zly-mac"
disk := "/dev/nvme0n1"
repo := "/persistent/nixos-config"
key_dir_rel := ".keys"
age_key_rel := "{{key_dir_rel}}/main.agekey"

# ========== 系统管理 ==========

# 新建 NixOS 主机目录（复制现有模板主机，默认来自 zly）
new-nixos-host name from="zly":
    {{repo}}/scripts/new-host.sh nixos {{name}} --from {{from}} --repo {{repo}}

# 预览 NixOS 主机脚手架（不写入文件）
new-nixos-host-dry-run name from="zly":
    {{repo}}/scripts/new-host.sh nixos {{name}} --from {{from}} --repo {{repo}} --dry-run

# 强制覆盖 NixOS 主机目录
new-nixos-host-force name from="zly":
    {{repo}}/scripts/new-host.sh nixos {{name}} --from {{from}} --repo {{repo}} --force

# 新建 Darwin 主机目录（复制现有模板主机，默认来自 zly-mac）
new-darwin-host name from="zly-mac":
    {{repo}}/scripts/new-host.sh darwin {{name}} --from {{from}} --repo {{repo}}

# 预览 Darwin 主机脚手架（不写入文件）
new-darwin-host-dry-run name from="zly-mac":
    {{repo}}/scripts/new-host.sh darwin {{name}} --from {{from}} --repo {{repo}} --dry-run

# 强制覆盖 Darwin 主机目录
new-darwin-host-force name from="zly-mac":
    {{repo}}/scripts/new-host.sh darwin {{name}} --from {{from}} --repo {{repo}} --force

# Live ISO 安装前构建校验（不落盘）
install-live-check:
    nix build --no-link .#nixosConfigurations.{{host}}.config.system.build.toplevel

# Live ISO 本机自动识别主机后执行安装前构建校验（严格模式：不允许 fallback）
install-live-check-local:
    host="$({{repo}}/scripts/resolve-host.sh nixos {{repo}} {{host}} --strict)"; echo ">>> host=$host"; just host="$host" install-live-check

# Live ISO 一键安装（危险：会清空 {{disk}}，并同步仓库到 /mnt/persistent/nixos-config）
install-live:
    @echo ">>> host={{host}} disk={{disk}}"
    disko_script="$(env NIXOS_DISK_DEVICE={{disk}} nix build --impure --no-link --print-out-paths path:{{repo}}#nixosConfigurations.{{host}}.config.system.build.diskoScript)"; \
      echo ">>> disko_script=$disko_script"; \
      sudo env NIXOS_DISK_DEVICE={{disk}} "$disko_script"
    findmnt /mnt/boot
    findmnt /mnt/persistent
    sudo rm -rf /mnt/persistent/nixos-config
    sudo mkdir -p /mnt/persistent/nixos-config
    if command -v rsync >/dev/null 2>&1; then \
      sudo rsync -a --delete --exclude='.git' --exclude='{{key_dir_rel}}' {{repo}}/ /mnt/persistent/nixos-config/; \
    else \
      echo "warning: rsync not found, fallback to cp -a (temporary .git copy will be removed)"; \
      sudo cp -a {{repo}}/. /mnt/persistent/nixos-config/; \
      sudo rm -rf /mnt/persistent/nixos-config/.git; \
      sudo rm -rf /mnt/persistent/nixos-config/{{key_dir_rel}}; \
    fi
    age_key_src="{{repo}}/{{age_key_rel}}"; \
      if [ -f "$age_key_src" ]; then \
        sudo install -D -m 0400 -o root -g root "$age_key_src" /mnt/persistent/keys/main.agekey; \
        echo ">>> agenix key installed: $age_key_src -> /mnt/persistent/keys/main.agekey"; \
      else \
        echo "error: agenix key not found at $age_key_src"; \
        echo "hint: put private key at {{repo}}/{{age_key_rel}} then retry"; \
        exit 1; \
      fi
    sudo env NIXOS_DISK_DEVICE={{disk}} nixos-install --impure --flake /mnt/persistent/nixos-config#{{host}}
    @echo ">>> github ssh key will be provisioned by agenix secrets on first boot/switch (if configured)"
    @echo "✓ 安装完成，重启后执行：just host={{host}} switch"

# Live ISO 本机自动识别主机后一键安装（严格模式：不允许 fallback）
install-live-local:
    host="$({{repo}}/scripts/resolve-host.sh nixos {{repo}} {{host}} --strict)"; echo ">>> host=$host disk={{disk}}"; just host="$host" disk="{{disk}}" install-live

# 应用配置并立即切换（常用）
switch:
    sudo nixos-rebuild switch --flake path:{{repo}}#{{host}} |& nom

# 自动识别当前机器主机名并切换（优先使用 NIXOS_HOST 覆盖）
switch-local:
    host="$({{repo}}/scripts/resolve-host.sh nixos {{repo}} {{host}})"; echo ">>> host=$host"; just host="$host" switch

# 应用配置但下次启动生效
boot:
    sudo nixos-rebuild boot --flake path:{{repo}}#{{host}} |& nom

# 临时测试配置（重启后失效）
test:
    sudo nixos-rebuild test --flake path:{{repo}}#{{host}} |& nom

# 自动识别当前机器主机名并 test
test-local:
    host="$({{repo}}/scripts/resolve-host.sh nixos {{repo}} {{host}})"; echo ">>> host=$host"; just host="$host" test

# 检查配置但不应用（快速验证）
check:
    nix build --no-link path:{{repo}}#nixosConfigurations.{{host}}.config.system.build.toplevel

# 自动识别当前机器主机名并 check
check-local:
    host="$({{repo}}/scripts/resolve-host.sh nixos {{repo}} {{host}})"; echo ">>> host=$host"; just host="$host" check

# 快速执行 eval tests（hostname/home 映射一致性）
eval-tests:
    @echo "=== checks.x86_64-linux (eval tests) ==="
    nix build --no-link \
      path:{{repo}}#checks.x86_64-linux.evaltest-hostname \
      path:{{repo}}#checks.x86_64-linux.evaltest-home
    @echo ""
    @echo "=== checks.aarch64-darwin (eval only) ==="
    nix eval path:{{repo}}#checks.aarch64-darwin.evaltest-darwin-hostname.drvPath >/dev/null
    nix eval path:{{repo}}#checks.aarch64-darwin.evaltest-darwin-home.drvPath >/dev/null

# 回滚到上一个系统世代
rollback:
    sudo nixos-rebuild switch --rollback

# ========== Darwin 管理 ==========

# 应用 macOS 配置（在 macOS 主机执行）
darwin-switch:
    darwin-rebuild switch --flake path:{{repo}}#{{darwin_host}}

# 自动识别当前机器主机名并切换 Darwin（优先使用 DARWIN_HOST 覆盖）
darwin-switch-local:
    host="$({{repo}}/scripts/resolve-host.sh darwin {{repo}} {{darwin_host}})"; echo ">>> darwin_host=$host"; just darwin_host="$host" darwin-switch

# 构建 macOS 配置（不切换；需在 macOS 或配置了 aarch64-darwin remote builder 的环境执行）
darwin-check:
    nix build --no-link path:{{repo}}#darwinConfigurations.{{darwin_host}}.system

# 自动识别当前机器主机名并构建 Darwin 配置
darwin-check-local:
    host="$({{repo}}/scripts/resolve-host.sh darwin {{repo}} {{darwin_host}})"; echo ">>> darwin_host=$host"; just darwin_host="$host" darwin-check

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

# Shell 脚本语法/静态检查（shellcheck 可选）
scripts-check:
    @bash -lc 'set -euo pipefail; shopt -s nullglob; files=(scripts/*.sh scripts/lib/*.sh .githooks/pre-*); if [ ${#files[@]} -eq 0 ]; then echo "warning: no shell scripts found"; exit 0; fi; bash -n "${files[@]}"; if command -v shellcheck >/dev/null 2>&1; then shellcheck "${files[@]}"; else echo "warning: shellcheck not found, skipped"; fi'
    @echo "✓ Shell 脚本检查通过"

# 查找死代码
dead:
    deadnix .

# 自动修复静态检查问题（谨慎使用）
fix:
    statix fix .
    @echo "✓ 自动修复完成"

# 完整代码检查（格式化 + 检查 + 死代码 + Shell）
check-all: fmt lint dead scripts-check
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

# 启用仓库内 git hooks（pre-commit / pre-push）
hooks-enable:
    git config core.hooksPath .githooks
    @echo "✓ 已启用 .githooks"

# 密钥泄露保护（阻止提交/推送敏感文件）
guard-secrets:
    @{{repo}}/scripts/guard-secrets.sh

# 初始化 agenix 主密钥（默认只同步，不自动创建）
agenix-init:
    @{{repo}}/scripts/bootstrap-age-key.sh

# 首次初始化 agenix 主密钥（仅在 main.agekey 缺失时创建）
agenix-init-create:
    @{{repo}}/scripts/bootstrap-age-key.sh --create

# 旋转 agenix 主密钥（危险：需要立即 rekey）
agenix-init-rotate:
    @{{repo}}/scripts/bootstrap-age-key.sh --rotate

# 初始化/更新恢复密钥（本地 .keys/recovery.agekey + 仓库公钥）
agenix-recovery-init:
    @{{repo}}/scripts/manage-agenix-recipients.sh init-recovery

# 添加主机 SSH host 公钥 recipient（默认读取 /etc/ssh/ssh_host_ed25519_key.pub）
agenix-host-key-add HOST PUB="/etc/ssh/ssh_host_ed25519_key.pub":
    @{{repo}}/scripts/manage-agenix-recipients.sh add-host '{{HOST}}' '{{PUB}}'

# 列出 agenix recipients
agenix-recipients:
    @{{repo}}/scripts/manage-agenix-recipients.sh list

# 按当前 recipients 重加密所有 secrets/*.age
agenix-rekey:
    @{{repo}}/scripts/manage-agenix-recipients.sh rekey

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

# 将同一个密码哈希写入 agenix（user/root）
password-set-hash HASH: agenix-init
    @{{repo}}/scripts/set-password-hash.sh '{{HASH}}'

# 将 .keys/github_id_ed25519(.pub) 加密写入 agenix secrets
ssh-key-set: agenix-init
    @{{repo}}/scripts/set-github-ssh-key.sh

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
    git commit -m "{{MESSAGE}}" -m "Co-Authored-By: Claude Sonnet 4.5 (1M context) <noreply@anthropic.com>"
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
    @echo "💿 安装（Live ISO）："
    @echo "  just host=zly install-live-check"
    @echo "  just host=zly disk=/dev/nvme0n1 install-live"
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
