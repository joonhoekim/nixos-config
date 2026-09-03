# Terminal hobby packages — docs: docs/packages/rice-toys.md
#
# None of this does any work. It is the r/unixporn half of the toolbox, kept in
# its own file for two reasons: packages.nix stays about tools, and the whole
# pile can be dropped by deleting one line there.
#
# Imported at the end of ./packages.nix, so everything here lands in the same
# profile as the rest. That means a name collision with a real tool would break
# the build — see the `sl` and `tt` notes below.
#
# The colour pipeline is deliberately absent: pywal16 (modules/darwin/rice) and
# matugen/DMS (modules/nixos/dms) already own wallpaper → palette. A second
# scheme generator (wallust, gowall) would just make "which one is canonical?"
# a question that has to be answered every time a colour looks wrong.

{ pkgs }:

with pkgs; [
  # ── Digital rain ────────────────────────────────────────────────────────
  # Two, because they look different. cmatrix is the one everyone recognises;
  # neo renders the actual film glyphs in 24-bit colour.
  cmatrix
  neo

  # ── Other animations ────────────────────────────────────────────────────
  cbonsai        # a bonsai grows in the terminal; `-l` keeps it growing forever
  pipes-rs       # pipes.sh rewritten in rust — smoother, and it takes options
  asciiquarium   # ascii aquarium
  lavat          # lava lamp
  bb             # the AA-lib demo: an actual ascii-art demoscene production
  sl             # steam locomotive for when `ls` is mistyped. Installs `sl`,
                 # which nothing else in this profile claims.

  # ── Looking busy ────────────────────────────────────────────────────────
  genact         # endless plausible-looking build/scan/deploy output
  hollywood      # splits the screen and fills every pane with technobabble;
                 # wants a multiplexer (zellij is in packages.nix)

  # ── Shell greeters ──────────────────────────────────────────────────────
  # The reason a unixporn screenshot has something in the top-left corner.
  #
  # Only krabby is cheap enough to hang off shell startup unconditionally:
  # measured here at 5.0ms against colorscript's 118ms, because colorscript
  # forks a shell script per invocation while krabby is a single rust binary.
  # 118ms is felt on every new terminal, so put colorscript behind a command
  # rather than in .zshrc.
  dwt1-shell-color-scripts # `colorscript random` — Derek Taylor's collection
  krabby                   # pokemon sprites
  terminaltexteffects      # `tte` — pipe any stdin through a visual effect

  # ── Text decoration ─────────────────────────────────────────────────────
  lolcat         # rainbow pipe
  figlet         # big letters
  toilet         # big letters, in colour, with filters
  boxes          # draw a box around text
  cowsay         # the cow
  charasay       # the cow's colourful successor
  ponysay        # the cow, but a pony
  fortune        # feeds all of the above

  # ── Audio ───────────────────────────────────────────────────────────────
  cava           # the bars next to the terminal in every other screenshot

  # ── Fetch ───────────────────────────────────────────────────────────────
  # fastfetch and onefetch are in packages.nix and stay the default. These
  # cover angles fastfetch does not: cpufetch draws the CPU's actual core
  # topology, ipfetch reports the network side.
  macchina       # fastfetch with a different aesthetic (themeable panels)
  cpufetch       # CPU architecture art
  ipfetch        # the network counterpart
  hyfetch        # neofetch with pride flag palettes
  nerdfetch      # nerdfont glyph fetch, POSIX sh

  # ── Clocks ──────────────────────────────────────────────────────────────
  # tty-clock is the classic and is deliberately absent: nixpkgs marks it
  # broken on aarch64-darwin, and this file is shared with the darwin build.
  peaclock       # clock / timer / stopwatch, heavily configurable
  clock-rs       # simpler digital clock

  # ── Image → terminal ────────────────────────────────────────────────────
  # chafa (packages.nix) is the best of these and stays the default. The two
  # here are not duplicates: chafa paints with block glyphs, while
  # ascii-image-converter uses real ascii characters, and timg plays
  # animations and video rather than showing a still.
  ascii-image-converter
  timg

  # ── Typing ──────────────────────────────────────────────────────────────
  ttyper         # rust, the prettiest of the three
  typioca        # bubbletea TUI
  tt             # minimal and scriptable. Installs `tt` — no other package in
                 # this profile does.

  # ── Games ───────────────────────────────────────────────────────────────
  vitetris
  nsnake
  nudoku
  ninvaders
  moon-buggy
  nethack

  # ── Misc ────────────────────────────────────────────────────────────────
  nyancat
  terminal-parrot

  # ── Recording (the one genuinely useful group) ───────────────────────────
  # How a rice gets shown to anyone else, and how a terminal demo gets into
  # docs/. vhs is scripted, so the recording is reproducible rather than a
  # take that has to be re-performed.
  vhs            # .tape script → GIF/MP4/WebM
  asciinema      # record/replay a session as a cast file
  termsvg        # render an asciinema cast to animated SVG

  # No `nvtop` here: it is already installed, vendor-matched, by
  # ../nixos/amd.nix and ../nixos/intel.nix. Adding it again would also have to
  # pick `nvtopPackages.full` (there is no top-level `nvtop` attribute), and
  # that variant pulls the NVIDIA backend, which needs the unfree
  # cuda_nvml_dev — for hardware no host here has.
]
