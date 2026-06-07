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

  # Media-related packages
  emacs-all-the-icons-fonts
  dejavu_fonts
  fd
  font-awesome
  hack-font
  noto-fonts
  noto-fonts-color-emoji
  meslo-lgs-nf

  # Node.js: managed by mise (programs.mise in home-manager), not nixpkgs.
  # Run `mise use -g node@lts` after rebuild to install a node version.

  # Text and terminal utilities
  htop
  jetbrains-mono
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
