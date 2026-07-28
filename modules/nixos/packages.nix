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
  wl-clipboard    # wl-copy / wl-paste (Wayland clipboard — KDE)

  # Networking diagnostics (Linux variants)
  traceroute
  dnsutils        # dig, nslookup

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
