# ╔══════════════════════════════════════════════════════════════════════╗
# ║  PLACEHOLDER — replace on the MN56 itself before building this host.  ║
# ╚══════════════════════════════════════════════════════════════════════╝
#
# This must come from THAT machine — it pins root/boot filesystems, swap,
# disk/initrd kernel modules, and CPU microcode. On the Firebat MN56:
#
#   sudo nixos-generate-config --show-hardware-config \
#     > ~/path/to/nixos-config/hosts/nixos/mn56/hardware-configuration.nix
#   # or, right after the installer ran:
#   cp /etc/nixos/hardware-configuration.nix \
#      ~/path/to/nixos-config/hosts/nixos/mn56/hardware-configuration.nix
#
# Then `git add` it and: nixos-rebuild switch --flake .#mn56
#
# Until replaced the build fails loudly (no `fileSystems."/"`), which is
# intentional — better than silently building an unbootable system.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Intentionally empty. Replace the whole file as described above.
}
