{ lib, user, surface-pro-9-linux, ... }:

# Microsoft Surface Pro 9 (Intel i5-1235U, 16 GB). 윈도우와 듀얼부트.
# 기기 층(커널·iptsd·스피커 DSP)은 surface-pro-9-linux 레포의 nixosModules.default 가 낸다.
{
  imports = [
    ../common.nix
    ../../../modules/nixos/intel.nix
    ./hardware-configuration.nix
    surface-pro-9-linux.nixosModules.default
  ];

  hardware.surface-pro-9.enable = true;
  # 커널 패치를 바꿀 때마다 전체를 다시 컴파일하지 않게 한다(바뀐 오브젝트만). 캐시는 10 GiB 까지 찬다.
  hardware.surface-pro-9.kernel.ccacheDir = "/var/cache/ccache";

  # /boot 가 윈도우와 같이 쓰는 260 MiB ESP 다(윈도우 약 35 MiB). systemd-boot 는 새 세대의 커널·initrd 를
  # 먼저 쓰고 나서 옛것을 지우므로 한도 + 1 벌이 들어가야 한다. 넘치면 switch 가 "No space left" 로 실패한다.
  boot.loader.systemd-boot.configurationLimit = lib.mkForce 2;

  # 26.05 설치본으로 깔았다(nixos-generate-config 가 쓴 값).
  system.stateVersion = "26.05";
  home-manager.users.${user}.home.stateVersion = "26.05";
}
