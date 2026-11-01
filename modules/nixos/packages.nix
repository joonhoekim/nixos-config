{ pkgs, lib, bundles }:

with pkgs;
# 공유 도구(core 와 고른 묶음, ../shared/package-bundles.nix)에 더해 모든 NixOS 호스트에 깔리는 Linux 전용 도구.
# GUI 앱은 ./gui-apps.nix. `ios` 는 macOS 전용이라 건너뛴다.
let shared = import ../shared/packages.nix { inherit pkgs; }; in
shared.core
++ lib.concatMap (b: shared.${b} or [ ]) bundles
++ [

  # Security and authentication
  yubikey-agent

  # App and package management
  appimage-run
  gnumake
  home-manager

  # Media and design tools
  fontconfig

  # Audio tools
  pavucontrol

  # Text and terminal utilities
  unixtools.ifconfig
  unixtools.netstat

  # File and system utilities
  inotify-tools
  libnotify
  xdg-utils

  # Compilers / toolchain
  gcc

  # Linux system utilities
  psmisc
  usbutils
  pciutils
  man-pages
  man-pages-posix
  wl-clipboard

  # Networking diagnostics (Linux variants)
  traceroute
  dnsutils
  bandwhich

  # Input / display / session diagnostics (keyd 리맵이나 Wayland·Xwayland 차이를 볼 때)
  wev
  xev
  evtest
  wayland-utils
  mesa-demos
  vulkan-tools
  # 외장 모니터 DDC/CI. apps/ddc-probe 가 부르고, 권한은 programs.dms-shell 이 켜는 hardware.i2c 에서 온다.
  ddcutil

  # Hardware / power inspection (vendor-neutral; 벤더별 도구는 ./intel.nix · ./amd.nix)
  dmidecode
  lshw
  inxi
  acpi
  lm_sensors
  # SSD 가 너무 뜨거웠던 적이 있는지는 `sensors` 가 아니라 드라이브 로그가 답한다. 둘 다 root.
  # Linux 전용인 이유: nvme-cli 는 NVME_IOCTL_ADMIN_CMD(platforms.linux), Apple Silicon 은 내장 SSD 에
  # NVMe admin 통과가 없어 smartctl 이 외장 드라이브밖에 못 읽는다.
  nvme-cli        # `nvme smart-log /dev/nvme0`
  smartmontools   # `smartctl -a /dev/nvme0`
  powertop
  s-tui
  stress-ng
  pulsemixer

]
