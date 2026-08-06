{ pkgs }:

with pkgs; [
  # General packages for development and system management
  bash-completion
  bat
  btop
  coreutils
  killall
  openssh
  sqlite
  wget
  zip

  # Encryption and security tools
  age
  gnupg

  # Cloud-related tools and SDKs
  docker          # docker CLI (talks to the colima-managed daemon)
  docker-compose
  colima          # container runtime on macOS (Docker Desktop replacement)
  lima            # Linux VM layer colima builds on (provides `limactl`)

  # Note: fonts live in modules/shared/fonts.nix (registered via fonts.packages),
  # since fonts in systemPackages aren't picked up by the macOS font system.

  # Media-related packages
  fd

  # Node.js (+ bun, corepack-backed yarn/pnpm): declared in programs.mise
  # globalConfig in home-manager, not nixpkgs. Run `mise install` after
  # rebuild to materialize the declared tool versions.

  # Text and terminal utilities
  htop
  jq
  ripgrep
  tree
  tmux
  unzip
  zsh-powerlevel10k
  
  # Development tools
  curl
  gh
  terraform
  kubectl
  awscli2
  lazygit
  fzf
  uv             # fast Python package/venv manager
  delta          # syntax-highlighting pager for git diffs

  # PDF / document tooling
  poppler-utils  # pdftotext, pdfinfo, pdfimages, pdftoppm, ...

  # The global `python3`. Python is intentionally NOT managed by mise (see
  # programs.mise in home-manager.nix) so this nix interpreter is the one on
  # PATH, with analysis libraries pre-imported — `python3 -c 'import pymupdf'`
  # works in any shell, no per-project venv. Add libraries to this list and
  # rebuild; use uv per-project when a project needs pinned/extra deps.
  (python3.withPackages (ps: with ps; [
    # PDF
    pymupdf            # fitz / pymupdf — text, render, metadata
    pdfplumber         # strong table extraction
    pypdf              # page merge/split/rotate
    # XLSX
    openpyxl           # read/write cells & styles (pandas' xlsx engine)
    xlsxwriter         # create xlsx with charts/formatting
    # DOCX
    python-docx        # read/write .docx
    # CSV / dataframes
    pandas             # load+transform csv/xlsx/json (pulls numpy)
    tabulate           # pretty terminal tables
    # web / HTML
    httpx              # quick API calls (sync/async)
    beautifulsoup4     # HTML parsing
    lxml               # fast parser backend for bs4
    # helpers
    rich               # colored terminal output / tables / progress
    charset-normalizer # detect mangled CSV encodings (e.g. cp949)
  ]))
  yq-go          # jq for YAML (provides `yq`)
  cmake
  pkg-config

  # Language runtimes are NOT base-installed here. They're version-managed
  # per project: go / rust / java / node / bun via mise (see
  # programs.mise.globalConfig in home-manager.nix), and Python via `uv`
  # (above) — so versions stay project-pinned instead of global.

  # Modern CLI / TUI tools
  difftastic     # syntax-aware diff (used by `diff` alias)
  neovim
  yazi           # TUI file manager
  tealdeer       # fast `tldr` client
  dust           # friendlier du
  procs          # modern `ps`
  lazydocker     # TUI for docker

  # Modern CLI / TUI tools — extended set (ported from previous NixOS config).
  # atuin / zoxide / eza / pay-respects are enabled as programs in
  # home-manager.nix, so they're intentionally not listed here.
  fx             # interactive JSON viewer
  duf            # friendlier df
  fastfetch      # system info (neofetch successor)
  file           # file type detection
  lsof           # list open files
  p7zip          # 7z archives
  xz             # xz/lzma compression
  unrar          # rar extraction (unfree)
  glow           # markdown renderer
  navi           # interactive cheatsheets
  hyperfine      # CLI benchmarking
  tokei          # source line counter
  watchexec      # run a command when files change
  entr           # run a command when files change (classic)
  ouch           # universal (de)compression
  just           # command runner (make alternative)
  gum            # shell-script UI prompts (charm.sh)
  onefetch       # git repo summary
  zellij         # terminal multiplexer
  bottom         # system monitor (btm)
  ncdu           # disk usage TUI
  gitui          # fast git TUI
  tig            # git history viewer
  yt-dlp         # video downloader
  chafa          # terminal image viewer
  ffmpeg         # media transcoding
  postgresql     # psql + client libraries
  redis          # redis-cli (server runs via colima/docker)

  # Editor / LSP toolchain (system-wide; LazyVim/Mason would install these
  # per-user otherwise)
  helix          # modal editor
  nixd           # Nix LSP (alternative to nil below)
  lua-language-server
  stylua         # Lua formatter
  shellcheck     # shell linter
  shfmt          # shell formatter
  ruff           # Python linter/formatter (Rust-based)
  tree-sitter    # parser generator CLI

  # Infra / DB / network
  k9s            # Kubernetes TUI
  dive           # docker image layer explorer
  pgcli          # postgres CLI with autocomplete
  lazysql        # database TUI
  nmap           # network scanner
  mtr            # traceroute + ping
  iperf3         # network throughput
  gping          # ping with a graph
  xh             # modern HTTP client (httpie-compatible)
  dog            # modern dig
  mkcert         # locally-trusted dev HTTPS certificates
  cloudflared    # quick public tunnels for webhook/callback testing

  # Browser automation / web verification
  #
  # Why this exists: verifying a local web app by eye needs a browser an agent
  # can actually drive. The Claude-in-Chrome extension talks to the *live*
  # Chrome and silently stops working when it isn't connected, so these are the
  # headless, scriptable fallback that always works. Docs: docs/browser-tooling.md
  #
  # No `chromium` here: nixpkgs marks it unsupported on aarch64-darwin. Browsers
  # come from playwright-driver.browsers (pinned below) or the installed Chrome
  # cask. `lighthouse` is meta.broken in nixpkgs, so it's deliberately absent.
  playwright-mcp           # MCP server — gives Claude Code navigate/click/screenshot/console tools
  playwright               # CLI + library for ad-hoc scripts (`playwright screenshot`, codegen)
  playwright-driver.browsers # pinned Chromium/Firefox/WebKit; PLAYWRIGHT_BROWSERS_PATH is
                             # exported in modules/shared/programs/zsh.nix so nothing
                             # downloads a browser at runtime
  shot-scraper             # one-liner URL → PNG, and --javascript to pull values out of a page
  odiff                    # fast pixel diff — before/after and light/dark screenshot comparison
  imagemagick              # crop/annotate/montage screenshots (e.g. side-by-side theme pairs)
  htmlq                    # CSS selectors over HTML on the CLI — jq for server-rendered output
  lychee                   # link checker that actually fetches (catches live 404s, not just refs)

  # Nix tooling (handy while editing this config)
  nil            # Nix language server
  nixfmt         # Nix formatter (was nixfmt-rfc-style)
]
