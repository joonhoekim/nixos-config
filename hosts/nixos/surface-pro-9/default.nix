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
  # 기기 도우미(sp9-helperd, sp9-ctl): 프로필별 전력 제한, 충전 정책, 키보드 백라이트, 진단, 슬림펜 2
  # (펜 속도를 디지타이저에 돌려줘 연속 햅틱을 내게 하고, 펜을 커버에 놓으면 결합한다: sp9-ctl pen).
  hardware.surface-pro-9.helper.enable = true;
  # iptsd 대신 이 기기용으로 새로 쓴 터치·펜 데몬(sp9-digitizerd).
  hardware.surface-pro-9.touch.daemon = "digitizerd";
  # 기기 층 커널에서는 두 커널 인자가 필요 없다: 패치 0014 가 PSR1 을 고르고(i915.enable_psr 는 커널을 오염시킨다),
  # 0x1800 대역은 펌웨어가 예약한다. 실측은 surface-pro-9-linux docs/nixos.md 의 옵션 표. 화면이 깜빡이거나
  # 덮개·USB-C 조작 때 GPE 가 쌓이면 해당 줄을 지운다.
  hardware.surface-pro-9.kernelParams.psr = false;
  hardware.surface-pro-9.kernelParams.hpiosize = false;

  # IR 카메라(ST VD55G0): ipu-bridge 항목과 ST 드라이버. 둘은 함께 넣는다(하나만 있으면 앞뒤 카메라 노드가
  # 안 생길 수 있다). 출처·상태는 surface-pro-9-lab kernel/PROVENANCE.md 0027·0028, docs/ir-camera.md.
  boot.kernelPatches = [
    { name = "ipu-bridge-vd55g0"; patch = ./kernel/0027-media-ipu-bridge-Add-the-ST-VD55G0-SMO55F0.patch; }
    {
      name = "vd55g0";
      patch = ./kernel/0028-media-i2c-Add-the-ST-VD55G0-driver.patch;
      structuredExtraConfig = { VIDEO_VD55G0 = lib.kernel.module; };
    }
  ];

  # /boot 가 윈도우와 같이 쓰는 260 MiB ESP 다(윈도우 약 35 MiB). systemd-boot 는 새 세대의 커널·initrd 를
  # 먼저 쓰고 나서 옛것을 지우므로 한도 + 1 벌이 들어가야 한다. 넘치면 switch 가 "No space left" 로 실패한다.
  boot.loader.systemd-boot.configurationLimit = lib.mkForce 2;

  # 26.05 설치본으로 깔았다(nixos-generate-config 가 쓴 값).
  system.stateVersion = "26.05";
  home-manager.users.${user}.home.stateVersion = "26.05";
}
