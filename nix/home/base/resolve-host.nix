{ myvars, osConfig ? null }:
if osConfig != null && osConfig ? my && osConfig.my ? host then
  osConfig.my.host
else
  myvars
