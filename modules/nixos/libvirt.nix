{ pkgs, user, ... }:

# TrustNet 클라이언트를 돌릴 Windows 게스트용 libvirt/QEMU-KVM. 왜 VM 인가(서명 쪽이 Windows 전용): docs/windows-guest.md
# 처음 rebuild 뒤 한 번: sudo virsh net-start default && sudo virsh net-autostart default

{
  virtualisation.libvirtd = {
    enable = true;

    qemu = {
      package = pkgs.qemu_kvm;

      # Windows 11 은 UEFI 와 TPM 2.0 없이 설치를 거부한다. OVMF 는 이제 기본 등록이라 qemu.ovmf 는
      # 선언하면 평가 단계 assertion 이다 — 펌웨어는 virt-manager 에서 게스트마다 고른다.
      swtpm.enable = true;
    };
  };

  programs.virt-manager.enable = true;

  # 없으면 virsh·virt-manager 가 qemu:///system 에 붙을 때마다 root 를 묻는다.
  users.users.${user}.extraGroups = [ "libvirtd" ];

  environment.systemPackages = [
    # Windows 에는 virtio 드라이버가 없다. 이 패키지는 .iso 가 아니라 풀린 트리다 — SATA + e1000 으로
    # 설치한 뒤 virtio-win-guest-tools.exe 를 돌린다. iso 로 만드는 법: docs/windows-guest.md
    pkgs.virtio-win
  ];

  # 게스트는 192.168.122.1 로 호스트 nginx 에 닿는다. trustedInterfaces 가 아니라 443 만 연다 —
  # virbr0 를 믿으면 호스트의 모든 포트가 게스트에 열린다. DHCP·DNS 는 libvirt 가 따로 ACCEPT 를 넣는다.
  networking.firewall.interfaces."virbr0".allowedTCPPorts = [ 443 ];

  # spiceUSBRedirection 은 끈다(setuid helper). USB 토큰 인증서가 생기면 켠다.

}
