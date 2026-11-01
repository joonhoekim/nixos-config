# Registered via `fonts.packages` (hosts/darwin, hosts/nixos): on macOS a font in
# environment.systemPackages is NOT registered with the font manager, so terminals show broken glyphs.
# fontconfig 을 안 읽는 OnlyOffice 는 목록이 overlays/onlyoffice-fonts.nix 에 따로 있다(이유는 그 파일).
{ pkgs }:

with pkgs; [
  nerd-fonts.jetbrains-mono   # primary coding font
  nerd-fonts.hack
  nerd-fonts.meslo-lg         # "MesloLGS Nerd Font" — powerlevel10k's reference font
  nerd-fonts.symbols-only     # glyph-only fallback for any non-patched font

  noto-fonts
  noto-fonts-color-emoji
  font-awesome

  # noto-fonts 는 CJK 를 안 덮고 Nerd Font 에는 한글이 없다. 이 묶음이 없으면 OS 가 아무 한글
  # 폰트나 집는다(macOS 는 모노 터미널에 명조 PCMyungjo). 확인: `ghostty +show-face --string=한글`
  nerd-fonts.d2coding   # "D2CodingLigature Nerd Font" — Hangul exactly 2x latin width; terminal default
  sarasa-gothic         # "Sarasa Mono K" / "Sarasa Term K" (.ttc collections)
  noto-fonts-cjk-sans-static # -static: the default is VF-only (wght 100) and OnlyOffice draws it Thin
  pretendard            # UI/document sans (proportional; not for the terminal)

  # DMS bundles these itself (share/quickshell/dms/assets/fonts via Qt FontLoader, bypassing fontconfig),
  # so `fc-match Inter` failing is not a fallback. Installed for GTK, the terminal and DMS's greeter.
  inter
  material-symbols
  nerd-fonts.fira-code

  # Alternates for ricing: swapping a profile's font is then a settings change, not a rebuild.
  nerd-fonts.caskaydia-cove   # Cascadia Code + Nerd glyphs
  geist-font                  # Vercel's UI/mono pair
]
