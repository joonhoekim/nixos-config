{ pkgs, user, ... }:

# libvirt/QEMU-KVM, for one job: a Windows guest that can run the work app's
# TrustNet client.
#
# The signing half of that app's 공동인증 flow is a native Windows program. The
# browser SDK does not sign anything itself — it probes localhost:18448 (then
# 28448, 38448) for a local HTTPS daemon the installer puts there, and
# npkisign.js takes the non-win32 branch outright when
# navigator.platform.toLowerCase() !== "win32". So no amount of Linux-side work
# reaches it: Wine is out too, since the program is a service plus Windows
# certificate-store integration rather than a UI binary.
#
# What this box *can* do is serve the other end. nginx here already fronts the
# reproduced webapp (../nixos/nginx.nix), so a guest on the NAT network gets a
# complete loop: guest browser -> host nginx -> the TrustNet Tomcat container.
#
# Snapshots are the reason this is a VM and not the work laptop. The code path
# being tested is the *transition* — "not installed" to "installed" — so it has
# to be walked more than once, and qcow2 lets the pre-install state come back
# verbatim.

{
  virtualisation.libvirtd = {
    enable = true;

    qemu = {
      package = pkgs.qemu_kvm;

      # Windows 11 will not install without UEFI and a TPM 2.0, and refuses at
      # the first setup screen rather than saying which one is missing.
      #
      # Only the TPM needs declaring. The matching virtualisation.libvirtd.qemu
      # .ovmf submodule was removed from nixpkgs — every OVMF image QEMU ships
      # is now registered with libvirt by default, Secure Boot variants
      # included — and setting it is a build-time assertion, not a no-op.
      # Pick the firmware per guest in virt-manager instead ("Customize
      # configuration before install" -> Overview -> Firmware -> UEFI).
      #
      # swtpm is the emulated TPM. libvirt starts one per guest on demand once
      # this is set; the guest XML still needs a <tpm model='tpm-crb'> device,
      # which virt-manager adds when the OS profile is Windows 11.
      swtpm.enable = true;
    };
  };

  programs.virt-manager.enable = true;

  # libvirtd's socket is group-owned. Without this, virsh and virt-manager fall
  # back to prompting for root on every connection to qemu:///system.
  users.users.${user}.extraGroups = [ "libvirtd" ];

  environment.systemPackages = [
    # Windows ships no virtio drivers, so a guest put straight onto a virtio
    # disk cannot see it in setup. Note this package is the *extracted* driver
    # tree (amd64/w11/..., virtio-win-guest-tools.exe at the top level), not
    # the .iso the upstream project distributes — there is nothing here to
    # attach as a CD-ROM as-is.
    #
    # Simplest route for one guest: install on emulated SATA + e1000, which
    # need no drivers, then run virtio-win-guest-tools.exe afterwards and move
    # the devices over. If setup-time virtio is wanted instead, wrap the tree
    # first:
    #   xorriso -as mkisofs -o /var/lib/libvirt/images/virtio-win.iso \
    #     $(nix eval --raw nixpkgs#virtio-win.outPath)
    pkgs.virtio-win
  ];

  # The guest reaches the host at 192.168.122.1 on libvirt's default NAT
  # network. nginx binds 0.0.0.0, so the only thing in the way is this box's
  # firewall — which ../nixos/nginx.nix deliberately leaves shut, noting that
  # ports should open "only if another device on the LAN ever needs to reach
  # it". The guest is that device, so this is that exception, scoped to the
  # virtual bridge instead of every interface.
  #
  # Per-interface rather than networking.firewall.trustedInterfaces: trusting
  # virbr0 would expose every listening port on the host to the guest, and the
  # guest only needs 443. Guest DHCP and DNS still work without being listed —
  # libvirt inserts its own ACCEPT rules for those at the top of INPUT, ahead
  # of the nixos-fw chain.
  networking.firewall.interfaces."virbr0".allowedTCPPorts = [ 443 ];

  # Left off deliberately: virtualisation.spiceUSBRedirection.enable. It is how
  # a USB security token would be passed through to the guest, and some 공동인증서
  # are issued on one — but the certificate for this testing is a file, and the
  # option pulls in a setuid spice-client helper. Turn it on if a token shows up.

  # Not declared here: the `default` NAT network itself. libvirt ships the
  # definition but leaves activation to runtime state, and this repo does not
  # try to own that (same split as nginx.nix). Once, after the first rebuild:
  #
  #   sudo virsh net-start default
  #   sudo virsh net-autostart default
}
