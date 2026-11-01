# Terminal hobby packages — docs: docs/packages/rice-toys.md
# Same profile as the real tools, so a name collision with one breaks the build.

{ pkgs }:

with pkgs; [
  cmatrix
  neo

  cbonsai
  pipes-rs
  asciiquarium
  lavat
  bb
  sl             # `sl`: nothing else in this profile claims it

  genact
  # hollywood is Linux-only — see the tail of this file.

  # Only krabby is cheap enough for shell startup: 5.0ms vs colorscript's 118ms (measured here).
  dwt1-shell-color-scripts # `colorscript`
  krabby
  terminaltexteffects      # `tte`

  lolcat
  figlet
  toilet
  boxes
  cowsay
  charasay
  ponysay
  fortune

  cava

  macchina
  cpufetch
  ipfetch
  hyfetch
  nerdfetch

  # No tty-clock: nixpkgs marks it broken on aarch64-darwin, and this file is shared with darwin.
  peaclock
  clock-rs

  ascii-image-converter
  timg

  ttyper
  typioca
  tt             # `tt`: no other package in this profile claims it

  vitetris
  nsnake
  nudoku
  ninvaders
  moon-buggy
  nethack

  nyancat
  terminal-parrot

  vhs
  asciinema
  termsvg

  # No `nvtop`: ../nixos/amd.nix and intel.nix install it vendor-matched; there is no top-level
  # `nvtop`, and nvtopPackages.full pulls the NVIDIA backend (unfree cuda_nvml_dev).
]

# hollywood: nixpkgs wraps it with atop (systemd), so the darwin build fails at libudev-zero (sys/sysmacros.h).
++ lib.optionals stdenv.hostPlatform.isLinux [
  hollywood
]
