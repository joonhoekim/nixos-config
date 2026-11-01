{ lib, pkgs, ... }:

# GMKtec EVO-T1 — Core Ultra 9 285H (Arrow Lake-H), Arc 140T, NPU 4, 64 GB.
# 전체 그림: docs/hosts/evo-t1.md
{
  imports = [
    ../common.nix
    ../../../modules/nixos/intel.nix
    ./hardware-configuration.nix
  ];


  # 26.05 설치본으로 깔았다. common.nix 의 mkDefault 26.11 을 받으면 안 된다.
  system.stateVersion = "26.05";

  # thermald 2.5.12 는 Arrow Lake 를 adaptive_only 로 두는데(src/thd_platform_intel.cpp)
  # 이 펌웨어 DPTF 에 GDDV 가 없어 매 부팅 실패하고, switch 가 성공해도 exit 4 가 난다.
  services.thermald.enable = lib.mkForce false;

  # 한 ACP 카드의 프로필은 배타적이라 analog duplex(6565)가 HDMI(5965)를 이겨 모니터 스피커 sink 가 아예 안 생긴다.
  # ~/.local/state/wireplumber/default-profile 의 기존 항목이 이 규칙을 이기고, 모니터를 빼도 analog 로 안 돌아간다.
  services.pipewire.wireplumber.extraConfig."51-hdmi-audio-preference" = {
    "device.profile.priority.rules" = [
      {
        matches = [ { "device.name" = "alsa_card.pci-0000_00_1f.3"; } ];
        actions.update-props.priorities = [
          "output:hdmi-stereo+input:analog-stereo"
        ];
      }
    ];
  };

  # Level Zero 로더는 /run/opengl-driver/lib 를 안 찾아 NPU 가 조용히 사라진다(OpenVINO 에 ['CPU'] 만).
  # 기본 드라이버 목록을 대체하므로 다른 L0 드라이버는 여기 덧붙인다. GUI 에도 닿게 sessionVariables.
  environment.sessionVariables.ZE_ENABLE_ALT_DRIVERS =
    "/run/opengl-driver/lib/libze_intel_npu.so.1";

  # OpenVINO GPU 플러그인이 쓰는 OpenCL. 12세대 이상만 지원해 intel.nix 가 아니라 여기 둔다.
  hardware.graphics.extraPackages = [ pkgs.intel-compute-runtime ];

  environment.systemPackages = [
    # NPU 는 `nix develop .#npu` 로 쓴다 — libze_loader.so.1 을 못 찾는 이유는 flake.nix 의 그 셸 옆에.
    pkgs.openvino
  ];

  # 두 NVMe 모두 SMART 에 응답한다. 지원 장치가 없으면 smartd 는 시작부터 실패한다.
  services.smartd = {
    enable = true;
    autodetect = true;
  };

  # LVFS 에 이 기계용 펌웨어는 UEFI dbx 하나뿐이고 Secure Boot 가 꺼져 있어 쓸모가 없다.
  services.fwupd.enable = false;
}
