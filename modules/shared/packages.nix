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

  # Encryption and security tools — docs: docs/packages/security-hygiene.md
  age
  gnupg
  sops           # secrets-in-repo standard combo with age (env-per-stage .env)
  gitleaks       # secret scanner — pre-push hook / CI gate for cloned template repos
  osv-scanner    # lockfile vulnerability scan against OSV.dev (wider than `pnpm audit`)
  lefthook       # git hook manager — the thing that actually runs gitleaks on pre-push
  trivy          # superset scan: container image layers, IaC misconfig, secrets, licenses
  semgrep        # rule-based SAST; ships TS/JS rulesets and takes custom rules as YAML

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
  gron           # JSON → greppable `a.b[0] = "x"` lines; `gron -u` folds them back.
                 # Finds the path to a value without knowing the jq syntax first.
  jd-diff-patch  # `jd` — structural JSON diff/patch; API response regressions
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

  # AI coding agent. claude-code 와 달리 nixpkgs 로 둔다 — 래퍼가
  # OPENCODE_DISABLE_AUTOUPDATE 를 박아 자체 업데이트가 스토어와 싸울 일이
  # 없고, unstable 이 거의 매일 따라온다. 플러그인(oh-my-openagent)과 설정은
  # modules/shared/opencode 참고 — 그쪽은 Nix 가 관리하지 않는다.
  opencode

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
  d2             # text → diagram (SVG/PNG); renders without a browser, so an
                 # architecture sketch can be written and then looked at
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

  # Everyday convenience tools (non-dev QoL) — docs: docs/packages/everyday-tools.md
  #
  # Downloads / media — companions to yt-dlp/ffmpeg above
  gallery-dl     # yt-dlp for image galleries (twitter/pixiv/...)
  aria2          # multi-connection downloader; pairs as `yt-dlp --downloader aria2c`
  streamlink     # pipe live streams (twitch/youtube live) into mpv — the realtime gap yt-dlp leaves
  mediainfo      # codec/bitrate/resolution details — first stop for "why won't this file play"

  # Image post-processing
  exiftool       # read/strip metadata (GPS!) before sharing photos
  pngquant       # lossy PNG compression
  jpegoptim      # JPEG compression
  gifsicle       # GIF optimizer
  gifski         # high-quality video → GIF (better output than ffmpeg alone)

  # Documents / PDF — complements poppler-utils above
  pandoc         # universal document converter (md/docx/html/epub/...)
  qpdf           # PDF encrypt/decrypt/merge/split — the crypto side poppler doesn't do
  ocrmypdf       # add a text layer to scanned PDFs (bundles its own tesseract)
  (tesseract.override { enableLanguages = [ "kor" "eng" ]; }) # direct `tesseract` CLI with Korean traineddata

  # File transfer / sync
  rclone         # cloud storage (gdrive/s3/onedrive/...) sync & mount from the CLI
  croc           # machine-to-machine file transfer via relay + codeword — AirDrop stand-in

  # Korean-environment specifics
  unar           # extracts cp949/EUC-KR-named zips (Korean Windows) without mangling filenames
  zbar           # QR decode (`zbarimg`) — the other direction of qrencode below

  # Misc
  speedtest-cli  # bandwidth test from the terminal
  monolith       # archive a web page as a single self-contained HTML file

  # Editor / LSP toolchain (system-wide; LazyVim/Mason would install these
  # per-user otherwise). Docs: docs/packages/web-toolchain.md
  helix          # modal editor
  nixd           # Nix LSP (alternative to nil below)
  lua-language-server
  stylua         # Lua formatter
  shellcheck     # shell linter
  shfmt          # shell formatter
  ruff           # Python linter/formatter (Rust-based)
  tree-sitter    # parser generator CLI

  # Web language servers. Everything above covers nix / lua / shell / python;
  # these are the Next/Nest half, which is the daily driver.
  vtsls                             # TypeScript/TSX LSP — drives tsserver the way VSCode does
  vscode-langservers-extracted      # html / css / json / eslint language servers
  tailwindcss-language-server       # class-name completion + hover for Tailwind
  dockerfile-language-server        # Dockerfile LSP (binary is `docker-langserver`)
  yaml-language-server              # YAML LSP with schema validation (k8s, compose, Actions)

  # JS/TS formatters and linters. A project's own pinned prettier/eslint wins
  # whenever the project has one — these are the fallback for repos that ship
  # no config, and the fast path for a one-off check. biome does both jobs in
  # one binary with no config at all, which makes it the way to verify an edit
  # in a repo whose toolchain isn't installed yet.
  biome          # linter + formatter, config-optional
  prettierd      # prettier as a resident daemon (drops per-call node startup)
  eslint_d       # eslint as a resident daemon

  # Structural search and rewrite. ripgrep above matches text; this matches
  # syntax trees, which is what a codemod across a TS/TSX codebase needs —
  # `ast-grep run -p 'useEffect($$$A)' -l tsx --rewrite '…'`. `--json` output
  # means a script consumes the matches instead of re-parsing a human-shaped
  # report. `semgrep` in the security block above is the rule-file counterpart.
  #
  # The command is `ast-grep`, not upstream's `sg` alias — nixpkgs drops that
  # one because shadow already owns `sg` (setgid) on Linux.
  ast-grep       # the pattern is written as source code, per tree-sitter grammar

  # Text-file linters for the files around the code
  typos              # source-aware spell check (identifiers and comments, not prose)
  yamllint           # YAML lint
  yamlfmt            # YAML formatter
  markdownlint-cli2  # Markdown lint (this repo's docs/)

  # Kubernetes. kubectl is up in the development-tools block; these are the
  # layers around it — templating, log tailing, context switching, and an
  # offline schema check so a manifest error surfaces before a cluster sees it.
  k9s            # Kubernetes TUI
  kubernetes-helm # `helm` — chart install / template / diff
  kustomize      # overlay-based manifest patching (the non-templating half)
  stern          # tail logs across many pods and containers at once
  kubectx        # `kubectx` / `kubens` — switch cluster and namespace
  kubeconform    # validate manifests against k8s JSON schemas, offline

  # Container and CI definitions — the files that only get tested by being run
  dive           # docker image layer explorer
  hadolint       # Dockerfile linter (checks the shell inside RUN too)
  actionlint     # GitHub Actions workflow linter — expression and matrix errors
  act            # run those workflows locally in docker instead of push-and-pray

  # Infra / DB / network
  pgcli          # postgres CLI with autocomplete
  pg_activity    # live pg_stat_activity TUI — what is running and what is blocking
  sqlfluff       # SQL linter/formatter with a postgres dialect — checks hand-written
                 # SQL before it reaches the database
  iredis         # redis CLI with autocomplete (pgcli counterpart)
  lazysql        # database TUI
  nmap           # network scanner
  mtr            # traceroute + ping
  iperf3         # network throughput
  gping          # ping with a graph
  xh             # modern HTTP client (httpie-compatible)
  dog            # modern dig
  mkcert         # locally-trusted dev HTTPS certificates
  caddy          # reverse proxy + automatic local HTTPS — reproduce cross-subdomain
                 # cookie topologies. Docs: docs/packages/local-https-proxy.md
  cloudflared    # quick public tunnels for webhook/callback testing

  # Message brokers and gRPC — docs: docs/packages/backend-protocols.md
  #
  # The wire formats a Nest backend speaks that curl cannot reach. `websocat`
  # (the WebSocket one) sits in the browser block below, since it is usually
  # pointed at the same dev server as the rest of that group.
  #
  # No RabbitMQ client here: nixpkgs dropped `amqp-tools`, and `rabbitmqadmin`
  # ships inside the broker package rather than standalone. Its management API
  # is plain HTTP, so `xh` above already reaches it.
  kcat           # Kafka produce/consume/metadata from the shell (was kafkacat)
  natscli        # NATS `nats` CLI — pub/sub, JetStream streams and consumers
  nats-top       # per-connection and per-subject NATS traffic view
  grpcurl        # curl for gRPC; server reflection means no .proto file needed
  buf            # proto lint, breaking-change detection against a baseline, codegen
  ghz            # gRPC load generator — k6/wrk's counterpart on this protocol

  # Local backing services — docs: docs/packages/local-backing-services.md
  #
  # Single binaries that stand in for the infrastructure a backend expects, so
  # one feature can be exercised without bringing up a compose file. Each keeps
  # its state in a directory you pass it and exits with the shell.
  #
  # No `minio`: upstream abandoned it and nixpkgs marks it insecure (six
  # unfixed CVEs, one of them unauthenticated object write), so installing it
  # would mean opening permittedInsecurePackages system-wide for a dev stub.
  # seaweedfs takes that slot because `weed server -s3` needs no config file.
  # `garage` is the other migration target nixpkgs names — reach for it when
  # the store has to look like production (cluster layout, durable
  # replication), which costs a TOML config and a layout-assign step first.
  mailpit         # SMTP sink + web UI — signup/reset mail with no real sender
  seaweedfs       # `weed` — S3-compatible object store, for upload paths
  minio-client    # `mc` — S3 client; drives seaweedfs, garage and real S3 alike
  process-compose # compose syntax over plain processes (web + api + worker);
                  # `-t=false` runs it headless for scripts and CI

  # Browser automation / web verification
  #
  # Why this exists: verifying a local web app by eye needs a browser an agent
  # can actually drive. The Claude-in-Chrome extension talks to the *live*
  # Chrome and silently stops working when it isn't connected, so these are the
  # headless, scriptable fallback that always works. Docs: docs/packages/browser-tooling.md
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
  hurl                     # HTTP contract tests as plain-text files — asserts on status/JSONPath/headers
  mitmproxy                # HTTPS-decrypting proxy — see/replay what the app actually sends over the wire
  miniserve                # single-binary static file server (CORS/SPA flags) — the file:// workaround
  websocat                 # curl for WebSockets — the one protocol the rest of this list can't speak
  k6                       # load/perf smoke tests scripted in JS
  wrk                      # dumb-simple HTTP throughput check when k6 is overkill
  oha                      # same job as wrk with a live histogram and `--json` output
  html-tidy                # HTML validator/pretty-printer (`tidy`) — catches malformed markup htmlq glosses over

  # Mobile / on-device web verification — docs: docs/packages/mobile.md
  #
  # The gap this fills: everything above verifies a web app on *this* machine;
  # none of it can reach a phone. adb is also the missing piece for PWA work —
  # remote-debugging device Chrome (chrome://inspect) and `adb reverse
  # tcp:3000 tcp:3000` so the phone sees the local dev server. iOS-native
  # tooling is darwin-only and lives in ../darwin/packages.nix.
  #
  # Deliberately NOT here:
  # - Android SDK / Android Studio: the SDK is managed by Android Studio in
  #   practice (macOS: homebrew cask; NixOS: `android-studio` pkg per-host if
  #   ever needed). JDK via mise, gradle via each project's wrapper — same
  #   "no global language runtimes" rule as above.
  # - flutter: in nixpkgs, but version-sensitive per project — fvm/mise
  #   territory, same reasoning as node/go/rust.
  # - fastlane: conventionally pinned per-project via Gemfile/bundler
  #   (plugins + version matter), so a global install works against the grain.
  # - PWA auditing (lighthouse/workbox/web-push): npm-ecosystem tools — `npx`
  #   in the project. lighthouse is also meta.broken in nixpkgs (see the
  #   browser-tooling note above). HTTPS-for-service-worker testing is already
  #   covered by caddy + mkcert.
  android-tools  # adb + fastboot — device Chrome remote debugging, port reverse, app install
  scrcpy         # mirror/control an Android device on the desktop (pairs with adb)
  qrencode       # terminal QR codes — hand a dev/tunnel URL to a phone in one line
  # Ahead-of-need (declared now so the first RN/mobile project starts warm):
  watchman       # file watcher React Native/Metro expects
  maestro        # mobile E2E flows (simulator/emulator) — Playwright's mobile counterpart
  bundletool     # AAB ↔ APK — only matters at store-distribution time

  # Nix tooling (handy while editing this config) — docs: docs/packages/nix-hygiene.md
  nil            # Nix language server
  nixfmt         # Nix formatter (was nixfmt-rfc-style)
  statix         # Nix linter — antipatterns, with autofix (`statix fix`)
  deadnix        # unused let-bindings and function arguments
  nix-output-monitor # `nom` — build progress as a live tree instead of a log wall
  nvd            # diff two generations: what a switch actually changed
  nix-tree       # interactive closure browser — where the gigabytes went
  nh             # nix helper; wraps rebuild with nom output and an nvd diff
]

# Terminal hobby packages live in their own file — nothing there does any work,
# and keeping it separate means the whole pile drops by deleting this line.
++ import ./rice-toys.nix { inherit pkgs; }
