{ pkgs }:

with pkgs; [
  # General packages for development and system management
  alacritty
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
  direnv
  uv             # fast Python package/venv manager
  delta          # syntax-highlighting pager for git diffs
  yq-go          # jq for YAML (provides `yq`)
  cmake
  pkg-config
  
  # Programming languages and runtimes
  go
  rustc
  cargo
  openjdk

  # Python packages
  python3
  virtualenv

  # Modern CLI / TUI tools
  difftastic     # syntax-aware diff (used by `diff` alias)
  neovim
  yazi           # TUI file manager
  tealdeer       # fast `tldr` client
  dust           # friendlier du
  procs          # modern `ps`
  lazydocker     # TUI for docker

  # Nix tooling (handy while editing this config)
  nil            # Nix language server
  nixfmt         # Nix formatter (was nixfmt-rfc-style)
]
