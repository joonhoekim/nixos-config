{ ... }:

# Firebat MN56 — Ryzen 7 7840HS (Phoenix, RDNA3 780M) mini PC.
# 전체 그림: docs/hosts/mn56.md
{
  imports = [
    ../common.nix
    ../../../modules/nixos/amd.nix
    # 회사 앱 폐쇄망 dev/qa 리버스 프록시 재현. /etc/nginx 는 그 저장소의 배포 스크립트가 관리한다.
    ../../../modules/nixos/nginx.nix
    # 공동인증 서명이 Windows 네이티브 프로그램이라 그 절반을 돌릴 Windows 게스트.
    ../../../modules/nixos/libvirt.nix
    ./hardware-configuration.nix
  ];


  # 26.05 설치본으로 깔았다(nixos-generate-config 가 쓴 값).
  system.stateVersion = "26.05";

  # 없으면 hibernate 가 다음 부팅이 복원하지 않는 이미지를 써서, 매번 조용히 데이터를 잃는 전원 재시작이 된다.
  # hardware-configuration.nix 의 swapDevices 와 같은 UUID.
  boot.resumeDevice = "/dev/disk/by-uuid/423f3ce2-ba0e-4ee3-a8a5-7868532f2201";

  # 기본 ACPI reboot 는 warm reboot 의 약 1/3 에서 POST 전에 멈춘다(10회 중 3회, 펌웨어 단).
  # 그래도 멈추면 reboot=bios, reboot=efi 순으로 시도한다.
  boot.kernelParams = [ "reboot=pci" ];

  # USB·네트워크 없이 BIOS 재플래시·롤백하는 경로. 절차: docs/postmortems/2026-08-13-mn56-bios-update.md
  boot.loader.systemd-boot.edk2-uefi-shell.enable = true;

  # 지원 장치가 없으면 smartd 가 시작부터 실패해서, 확인 안 된 galaxy-chromebook-1 때문에 common.nix 로 못 올린다.
  services.smartd = {
    enable = true;
    autodetect = true;
  };
}
