{ pkgs, ... }:
{
  security = {
    apparmor = {
      enable = true;
      packages = [ pkgs.apparmor-profiles ];
    };

    polkit = {
      enable = true;
    };
    rtkit.enable = true;
  };

  # 内核安全加固
  boot.kernel.sysctl = {
    # 限制 ptrace 范围：仅父进程可调试子进程
    "kernel.yama.ptrace_scope" = 1;
    # 隐藏内核指针，减少信息泄露
    "kernel.kptr_restrict" = 2;
    # 限制非特权用户读取 dmesg
    "kernel.dmesg_restrict" = 1;
    # 禁止非特权用户使用 eBPF，减少攻击面
    "kernel.unprivileged_bpf_disabled" = 1;
    # BPF JIT 加固
    "net.core.bpf_jit_harden" = 2;
    # 防止 SUID 程序产生 core dump（避免泄露特权进程内存）
    "fs.suid_dumpable" = 0;
    # 防止硬链接/符号链接攻击（非属主不可操作他人的 symlink/hardlink）
    "fs.protected_symlinks" = 1;
    "fs.protected_hardlinks" = 1;
    # 防止 FIFO/regular file 在 world-writable sticky 目录中被利用
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
  };
}
