{ lib, tb323fu-linux, ... }:

# Lenovo Y700 Gen 5 (TB323FU, "baldur"), Snapdragon 8 Elite Gen 5 태블릿. UFS 의 baldur-root 파티션.
# 기기 층(커널 스텁·펌웨어·DSP·센서·헬퍼)은 tb323fu-linux 레포의 nixosModules.rootfs 가 낸다.
#
# 기기에만 있는 값(Android 에서 뽑은 펌웨어, 센서 파일, 커널 config, root SSH 키, Android boot 해시)은
# 태블릿의 /etc/nixos 가 extendModules 로 더한다(local.nix, tb323fu-linux rootfs/nixos/build-rootfs.sh 가
# 쓰는 꼴). build·build-switch 는 그 wrapper 를 찾아 빌드한다(docs/hosts/baldur.md). local.nix 없이도
# 평가는 되지만 Wi-Fi · 소리 · DSP 가 안 뜨고 USB 망(192.168.7.2)과 root SSH 가 사라진다.
{
  imports = [
    ../common.nix
    tb323fu-linux.nixosModules.rootfs
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  tb323fu.rootfs = {
    # initramfs 가 기본으로 띄우는 파티션. 부팅 선택과 커널 시험 상태(/etc/tb323fu, /var/lib/tb323fu)도 여기 둔다.
    partlabel = "baldur-root";
    # 로그인 화면과 세션은 common.nix(subline greeter)가 정한다. "gnome" 은 GDM 자동 로그인이라 겹친다.
    desktop = "none";
  };

  # 부트로더는 Android 의 boot_a(커널 + initramfs)이고, initramfs 가 시스템 프로필을 바로 띄운다. EFI 가 없다.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # devAccess 의 usb0 용 networkd 가 resolved 를 따라 켜는데, 이름 풀이는 desktop.nix 의 NetworkManager dnsmasq 가 맡는다.
  services.resolved.enable = false;
}
