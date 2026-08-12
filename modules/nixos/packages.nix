{ pkgs }:

with pkgs;
let shared-packages = import ../shared/packages.nix { inherit pkgs; }; in
shared-packages ++ [

  # Security and authentication
  yubikey-agent

  # App and package management
  appimage-run
  gnumake
  home-manager

  # Media and design tools
  fontconfig

  # Productivity tools

  # Audio tools
  pavucontrol # Pulse audio controls

  # Text and terminal utilities
  unixtools.ifconfig
  unixtools.netstat

  # File and system utilities
  inotify-tools # inotifywait, inotifywatch - For file system events
  libnotify
  xdg-utils

  # Other utilities
  google-chrome

  # PDF viewer
  zathura

  # ── Ported from previous NixOS config (Linux-only or GUI). Cross-platform
  #    CLI/TUI tools live in ../shared/packages.nix instead. GUI apps on
  #    macOS are managed via homebrew casks (modules/darwin/casks.nix). ──

  # Compilers / toolchain
  gcc

  # Linux system utilities
  psmisc          # killall, pstree, fuser
  usbutils        # lsusb
  pciutils        # lspci
  man-pages
  man-pages-posix
  wl-clipboard    # wl-copy / wl-paste (Wayland clipboard)

  # Networking diagnostics (Linux variants)
  traceroute
  dnsutils        # dig, nslookup
  bandwhich       # per-process network usage

  # Input / display / session diagnostics. Mostly earn their keep when a
  # remap (keyd, see keyboard.nix) or a Wayland-vs-Xwayland difference misbehaves.
  wev             # Wayland event viewer (keys, pointer, touch)
  xev             # X11 event viewer (for Xwayland apps)
  evtest          # raw evdev events per /dev/input/event*
  wayland-utils   # `wayland-info` — compositor + supported protocols
  mesa-demos      # glxinfo, eglinfo, glxgears
  vulkan-tools    # vulkaninfo, vkcube
  # 외장 모니터와 DDC/CI 로 말하는 도구 — 밝기·명암·입력 소스 등. apps/ddc-probe
  # 가 이것을 부르고, 그 파일 머리말에 "왜 되읽기만으로는 판정이 안 되는가" 가
  # 있다. 접근 권한은 programs.dms-shell 이 켜는 hardware.i2c 에서 온다.
  ddcutil

  # Hardware / power inspection (vendor-neutral; per-vendor tools such as
  # intel-gpu-tools live in the host dirs under hosts/nixos)
  dmidecode       # BIOS / motherboard / chassis info
  lshw            # detailed hardware tree
  inxi            # one-shot system summary
  acpi            # battery / thermal zones
  lm_sensors      # `sensors` — read all temp sensors
  # Storage health. `sensors` only ever shows an SSD's *current* temperature;
  # these two read the drive's own logs, which is what actually answers
  # "has it ever been too hot?" — nvme-cli for the NVMe-only fields
  # (Warning/Critical Composite Temperature Time, Thermal Management T1/T2
  # throttle counts, percentage_used), smartctl for the same SMART data over
  # SATA and USB bridges, which nvme-cli cannot reach. Both want root.
  #
  # Both stay Linux-only on purpose. nvme-cli has no choice — it drives the
  # Linux NVME_IOCTL_ADMIN_CMD ioctl, and nixpkgs marks it platforms.linux, so
  # putting it in ../shared would break the darwin build. smartmontools does
  # build on aarch64-darwin, but Apple Silicon keeps the internal SSD behind
  # the ANS controller and exposes no NVMe admin passthrough, so smartctl reads
  # nothing there beyond external USB/Thunderbolt drives. Keeping the pair
  # together here beats splitting the explanation across two files.
  nvme-cli        # `nvme smart-log /dev/nvme0`
  smartmontools   # `smartctl -a /dev/nvme0`
  powertop        # power-usage analyzer + tuning suggestions
  s-tui           # TUI: stress + temperature + frequency graphs
  stress-ng       # stress tester (useful to verify thermal behavior)
  pulsemixer      # pipewire/pulse volume TUI (CLI counterpart to pavucontrol)

  # GUI applications
  vscode
  brave
  firefox-devedition
  claude-code     # CLI, but already provided via mise/npm on macOS
  mpv             # video player
  krita           # digital painting
  gimp            # image editor
  inkscape        # vector graphics

  # ── Counterparts to the homebrew casks in modules/darwin/casks.nix ──
  # Everything here is a cask on macOS that also ships for Linux in nixpkgs.
  # Casks with no Linux counterpart stay macOS-only on purpose: iterm2
  # (macOS-only terminal), aerospace (tiling WM), karabiner-elements (keyd
  # handles remaps here, see
  # keyboard.nix), eul / stats (macOS menu-bar monitors — btop/bottom above),
  # and iina (mpv above is the same engine).
  ghostty                    # terminal (cask "ghostty")
  zed-editor                 # editor (cask "zed")
  dbeaver-bin                # universal database tool / SQL client
  redisinsight               # official Redis GUI
  postman                    # API client
  bruno                      # git-friendly API client
  onlyoffice-desktopeditors  # office suite
]
