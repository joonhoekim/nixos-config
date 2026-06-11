{ pkgs, ... }:

# Intel host (e.g. 14900HX / 285H). Modern Intel iGPUs use i915/xe + mesa;
# intel-media-driver adds VAAPI/QSV hardware video decode. CPU microcode is
# handled by the generated hardware-configuration.nix.
{
  imports = [
    ../common.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "intel";

  # Intel hardware video acceleration (iHD / VAAPI).
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
  ];
}
