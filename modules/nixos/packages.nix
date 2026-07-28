{ pkgs }:

with pkgs;
let shared-packages = import ../shared/packages.nix { inherit pkgs; }; in
shared-packages ++ [

  # Security and authentication
  yubikey-agent

  # App and package management
  appimage-run
  gnumake
  cmake
  home-manager

  # Media and design tools
  fontconfig

  # Productivity tools

  # Audio tools
  pavucontrol # Pulse audio controls

  # Text and terminal utilities
  tree
  unixtools.ifconfig
  unixtools.netstat

  # File and system utilities
  inotify-tools # inotifywait, inotifywatch - For file system events
  libnotify
  sqlite
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
  # remap (keyd, see korean.nix) or a Wayland-vs-Xwayland difference misbehaves.
  wev             # Wayland event viewer (keys, pointer, touch)
  xev             # X11 event viewer (for Xwayland apps)
  evtest          # raw evdev events per /dev/input/event*
  wayland-utils   # `wayland-info` — compositor + supported protocols
  mesa-demos      # glxinfo, eglinfo, glxgears
  vulkan-tools    # vulkaninfo, vkcube

  # Hardware / power inspection (vendor-neutral; per-vendor tools such as
  # intel-gpu-tools live in the host dirs under hosts/nixos)
  dmidecode       # BIOS / motherboard / chassis info
  lshw            # detailed hardware tree
  inxi            # one-shot system summary
  acpi            # battery / thermal zones
  lm_sensors      # `sensors` — read all temp sensors
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
]
