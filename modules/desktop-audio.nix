{ ... }:
{
  # 音频（含 32 位支持，便于 Steam/Proton）
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}
