# ╔══════════════════════════════════════════════════════════════════════╗
# ║  PLACEHOLDER — replace on the Intel machine before building this host. ║
# ╚══════════════════════════════════════════════════════════════════════╝
#
# This must come from THIS machine — it pins root/boot filesystems, swap,
# disk/initrd kernel modules, and CPU microcode. On the target Intel machine:
#
#   cp /etc/nixos/hardware-configuration.nix \
#      ~/path/to/nixos-config/hosts/nixos/intel/hardware-configuration.nix
#   # or: sudo nixos-generate-config --show-hardware-config \
#   #        > hosts/nixos/intel/hardware-configuration.nix
#
# Then `git add` it and: nixos-rebuild switch --flake .#intel
#
# Until replaced the build fails loudly (no `fileSystems."/"`), which is
# intentional — better than silently building an unbootable system.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Intentionally empty. Replace the whole file as described above.
}
