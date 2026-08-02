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
  nerd-fonts.meslo-lg         # "MesloLGS Nerd Font" — powerlevel10k's reference font
  nerd-fonts.symbols-only     # glyph-only fallback for any non-patched font

  # Coverage / emoji
  noto-fonts
  noto-fonts-color-emoji
  font-awesome

  # ── Korean / CJK ───────────────────────────────────────────────────────
  # noto-fonts above does NOT cover CJK — nixpkgs splits that out — and no
  # Nerd Font is patched with Hangul. So without this block a machine can end
  # up with zero Korean faces of its own, and the OS picks one for you: macOS
  # was rendering Hangul in PCMyungjo, a serif face, inside a mono terminal.
  # That is what "한글만 폰트가 다르다" looks like. Check with
  # `ghostty +show-face --string=한글`.
  #
  # NixOS had these already (modules/nixos/korean.nix); they live here now so
  # both platforms get the same faces and the terminal config can name one.
  nerd-fonts.d2coding   # "D2CodingLigature Nerd Font" — Hangul cells exactly 2x
                        # the latin ones, so columns don't drift. Terminal default.
  sarasa-gothic         # "Sarasa Mono K" / "Sarasa Term K" — Iosevka + Source Han.
                        # Ships as .ttc collections; one file holds every language cut.
  noto-fonts-cjk-sans   # coverage insurance — nothing should render as □
  pretendard            # UI/document sans (proportional; not for the terminal)

  # ── UI / ricing ────────────────────────────────────────────────────────
  # DankMaterialShell does NOT need these: it bundles Inter, FiraCode Nerd
  # Font and Material Symbols under share/quickshell/dms/assets/fonts and
  # loads them with Qt FontLoader, which bypasses fontconfig entirely. So
  # `fc-match Inter` failing does not mean the shell is falling back.
  #
  # They are installed anyway so *everything else* can use the same faces —
  # GTK apps, the terminal, and DMS's own greeter mode, which runs before the
  # user session and reads fontconfig rather than the bundled assets.
  inter
  material-symbols
  nerd-fonts.fira-code

  # Alternates worth having on hand while ricing; swapping a profile's font
  # is then a settings change instead of a rebuild.
  nerd-fonts.caskaydia-cove   # Cascadia Code + Nerd glyphs
  geist-font                  # Vercel's UI/mono pair
]
