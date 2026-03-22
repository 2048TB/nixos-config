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
  };
}
