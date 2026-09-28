# bash 와 zsh 가 같이 읽는 초기화 조각. programs/bash.nix 와 programs/zsh.nix 가
# 각자의 init 에 이 문자열을 넣는다.
#
# programs/ 의 조각이 아니라 여기 있는 이유: programs/ 의 파일은 전부
# `programs`-모양 어트리뷰트셋을 돌려줘야 하고(home-manager.nix 의 폴드), 이건
# 문자열이다.
#
# 두 셸에서 똑같이 파싱되어야 한다. `[[ ]]`, `(( ))`, `local` 은 둘 다 되지만
# zsh 전용 문법(glob 한정자, `setopt`)이나 bash 전용 문법(`shopt`)은 여기 두지 않고
# 각 셸의 파일에 둔다.
{ pkgs, lib }:
''
  if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
  fi

  # Define variables for directories
  export PATH=$HOME/.pnpm-packages/bin:$HOME/.pnpm-packages:$PATH
  export PATH=$HOME/.npm-packages/bin:$HOME/bin:$PATH
  export PATH=$HOME/.local/share/bin:$PATH
  export PATH=$HOME/.local/bin:$PATH   # user-local bins (e.g. claude)

  # Remove history data we don't want to see
  export HISTIGNORE="pwd:ls:cd"

  # Editor
  export EDITOR="vim"
  export VISUAL="vim"

  # Playwright uses the nix-pinned browser bundle instead of downloading its
  # own into ~/Library/Caches. Without SKIP_BROWSER_DOWNLOAD, `npm i
  # playwright` in any project re-downloads ~400MB and then runs a browser
  # nix doesn't know about. See docs/packages/browser-tooling.md.
  export PLAYWRIGHT_BROWSERS_PATH="${pkgs.playwright-driver.browsers}"
  export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

  # nix shortcuts
  shell() {
      nix-shell '<nixpkgs>' -A "$1"
  }

  # Use difftastic, syntax-aware diffing
  alias diff=difft

  # Always color ls and group directories
  alias ls='ls --color=auto'

  # Claude Code without permission prompts
  alias cld='claude --dangerously-skip-permissions'
'' + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin
  ("\n" + builtins.readFile ../darwin/scripts/colima-up.sh)
