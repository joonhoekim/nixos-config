# Shared font packages for both macOS (nix-darwin) and NixOS.
#
# Registered via `fonts.packages` on each platform (see hosts/darwin and
# hosts/nixos). On macOS this is what actually exposes fonts to apps —
# putting a font in environment.systemPackages does NOT register it with
# the system font manager, so terminals can't find it (cue broken glyphs).
#
# Nerd Fonts provide the powerline/devicon glyphs that prevent symbol
# corruption ("기호 깨짐") in terminals, shells (powerlevel10k), and TUIs.
{ pkgs }:

with pkgs; [
  # Nerd Fonts (patched with extra glyphs/icons)
  nerd-fonts.jetbrains-mono   # primary coding font (matches nixpkgs jetbrains-mono)
  nerd-fonts.hack
  nerd-fonts.meslo-lg         # alacritty family "MesloLGS Nerd Font" (+ powerlevel10k)
  nerd-fonts.symbols-only     # glyph-only fallback for any non-patched font

  # Coverage / emoji
  noto-fonts
  noto-fonts-color-emoji
  font-awesome
]
