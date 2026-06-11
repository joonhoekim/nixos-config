{ ... }:

# AMD host (e.g. Ryzen 7840HS / RDNA3 iGPU). amdgpu + mesa need no extra
# packages — integrated graphics and CPU microcode are handled by mesa and
# the generated hardware-configuration.nix respectively.
{
  imports = [
    ../common.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "amd";

  # Machine-specific tweaks go here.
}
