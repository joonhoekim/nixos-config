# `{ <묶음> = [ ... ]; }` 를 돌려주고 부르는 쪽이 고른 묶음만 잇는다. 전체 그림: docs/packages/README.md
{ pkgs }:

with pkgs; {
  core = [
    bash-completion
    bat
    btop
    coreutils
    killall
    openssh
    wireguard-tools # client only; configs/keys stay in /etc/wireguard/ — docs/wireguard.md
    sqlite
    wget
    zip

    # Encryption and secrets hygiene — docs: docs/packages/security-hygiene.md
    age
    gnupg
    sops
    gitleaks
    lefthook       # runs gitleaks on pre-push

    fd

    htop
    jq
    gron
    jd-diff-patch  # `jd`
    ripgrep
    tree
    tmux
    unzip
    zsh-powerlevel10k

    curl
    gh
    lazygit
    fzf
    uv
    delta

    poppler-utils
    qpdf

    # The global `python3`: Python is NOT managed by mise (programs/cli.nix), so this one is on PATH
    # with these libraries pre-imported. Per-project pins go to uv.
    (python3.withPackages (ps: with ps; [
      pymupdf
      pdfplumber
      pypdf
      openpyxl           # pandas' xlsx engine
      xlsxwriter
      python-docx
      pandas
      tabulate
      httpx
      beautifulsoup4
      lxml               # parser backend for bs4
      rich
      charset-normalizer # detect mangled CSV encodings (e.g. cp949)
    ]))
    yq-go          # `yq`
    cmake
    pkg-config

    # Runtimes (go / rust / java / node / bun) come from mise (programs/cli.nix), Python per project from uv.

    difftastic     # backs the `diff` alias
    neovim
    yazi
    tealdeer       # `tldr`
    dust
    procs

    # atuin / zoxide / eza / pay-respects are home-manager programs (programs/cli.nix), not listed here.
    fx
    duf
    fastfetch
    file
    lsof
    p7zip
    xz
    unrar          # unfree
    glow
    navi
    hyperfine
    tokei
    watchexec
    entr
    ouch
    just
    gum
    onefetch
    zellij
    bottom         # `btm`
    ncdu
    gitui
    tig
    chafa

    # docs: docs/packages/everyday-tools.md
    rclone
    croc

    unar           # cp949/EUC-KR-named zips (Korean Windows) without mangling filenames
    zbar           # `zbarimg`

    speedtest-cli
    monolith

    # Editor / LSP for this repo's own languages (nix / lua / shell / python) — docs: docs/packages/web-toolchain.md
    helix
    nixd
    lua-language-server
    stylua
    shellcheck
    shfmt
    ruff
    tree-sitter

    # The command is `ast-grep`: nixpkgs drops upstream's `sg` alias because shadow owns `sg` on Linux.
    ast-grep

    typos
    yamllint
    yamlfmt
    markdownlint-cli2

    nmap
    mtr
    iperf3
    gping
    xh
    dog

    # docs: docs/packages/nix-hygiene.md
    nil
    nixfmt
    statix
    deadnix
    nix-output-monitor # `nom`
    nvd
    nix-tree
    nh
  ];

  # trivy and semgrep-core are ~200M apiece.
  security = [
    osv-scanner
    trivy
    semgrep
  ];

  # colima pulls lima → qemu (~0.8G). `colima-up` (../darwin/scripts/colima-up.sh) exists only with this bundle.
  containers = [
    docker
    docker-compose
    colima
    lima            # `limactl`
    lazydocker
    dive
    hadolint
    actionlint
    act
  ];

  cloud = [
    terraform
    awscli2
    kubectl
    k9s
    kubernetes-helm # `helm`
    kustomize
    stern
    kubectx        # `kubectx` / `kubens`
    kubeconform
  ];

  # Docs: docs/packages/backend-protocols.md, docs/packages/local-backing-services.md
  backend = [
    postgresql
    redis          # client only; the server runs via colima/docker
    pgcli
    pg_activity
    sqlfluff
    iredis
    lazysql

    # `websocat` is in the web bundle. No RabbitMQ client: its management API is HTTP, `xh` reaches it.
    kcat
    natscli        # `nats`
    nats-top
    grpcurl
    buf
    ghz

    # No `minio`: nixpkgs marks it insecure, so it would mean permittedInsecurePackages system-wide.
    mailpit
    seaweedfs       # `weed`
    minio-client    # `mc`
    process-compose # `-t=false` runs it headless
  ];

  # PLAYWRIGHT_BROWSERS_PATH (../shell-init.nix) is exported only with this bundle.
  web = [
    vtsls
    vscode-langservers-extracted
    tailwindcss-language-server
    dockerfile-language-server        # binary is `docker-langserver`
    yaml-language-server

    # Fallback for repos that ship no prettier/eslint config; a project's own pinned one wins.
    biome          # needs no config at all
    prettierd
    eslint_d

    # docs: docs/packages/local-https-proxy.md
    mkcert
    caddy
    cloudflared

    # docs: docs/packages/browser-tooling.md. No `chromium` (unsupported on aarch64-darwin) and
    # no `lighthouse` (meta.broken) — browsers come from playwright-driver.browsers or the Chrome cask.
    playwright-mcp
    playwright
    playwright-driver.browsers # pinned; ../shell-init.nix points PLAYWRIGHT_BROWSERS_PATH here
    shot-scraper
    odiff
    imagemagick
    htmlq
    lychee
    hurl
    mitmproxy
    miniserve
    websocat
    k6
    wrk
    oha
    html-tidy                # `tidy`
  ];

  # docs: docs/packages/everyday-tools.md
  media = [
    yt-dlp
    ffmpeg
    gallery-dl
    aria2          # `yt-dlp --downloader aria2c`
    streamlink
    mediainfo

    exiftool
    pngquant
    jpegoptim
    gifsicle
    gifski
  ];

  # Split from core for size: pandoc ~230M. ocrmypdf gets the trimmed tesseract too — the stock one
  # references every language (~1G); aarch64-darwin closure 2794M → 1826M, at the cost of a local build (~80s).
  # `osd` is required: without it `--rotate-pages` fails with "Error opening data file …/osd.traineddata".
  documents = let
    tesseract' = tesseract.override { enableLanguages = [ "kor" "eng" "osd" ]; };
  in [
    pandoc
    (ocrmypdf.override { tesseract = tesseract'; })
    tesseract'

    # Linux 판은 PNG 내보내기용 playwright 브라우저까지 끌어와 1.3 GiB 라 core 에 안 둔다
    # (macOS 판 61 MiB, 둘 다 2026-11 cache.nixos.org 의 narSize).
    d2
  ];

  # docs: docs/packages/mobile.md (deliberately absent tools are listed there too)
  mobile = [
    android-tools  # adb + fastboot
    scrcpy
    qrencode
    watchman       # React Native/Metro expects it
  ];

  # Both run on a JDK (~0.35G) and maestro is ~0.35G on top, which is why they are not in `mobile`.
  mobile-e2e = [
    maestro
    bundletool
  ];

  # docs: docs/packages/rice-toys.md
  toys = import ./rice-toys.nix { inherit pkgs; };
}
