# bash·zsh 가 같이 읽는 init 문자열(programs/ 조각은 attrset 이어야 해서 여기 있다).
# 두 셸에서 똑같이 파싱돼야 한다 — `setopt`·`shopt`·glob 한정자는 각 셸 파일에 둔다.
{ pkgs, lib, bundles }:
let has = b: builtins.elem b bundles; in
''
  # 설치기의 nix-daemon.sh 는 source 하지 않는다 — 셸의 `nix` 가 데몬(nix.package)과 판이 갈리고 NIX_PROFILES
  # 에서 시스템·사용자 프로필이 조용히 빠진다. 확인: `command -v nix` 가 /run/current-system/sw/bin/nix
  # (apps/check/mac). 전체 그림: docs/nix-implementation.md

  export PATH=$HOME/.pnpm-packages/bin:$HOME/.pnpm-packages:$PATH
  export PATH=$HOME/.npm-packages/bin:$HOME/bin:$PATH
  export PATH=$HOME/.local/share/bin:$PATH
  export PATH=$HOME/.local/bin:$PATH   # user-local bins (e.g. claude)

  export HISTIGNORE="pwd:ls:cd"

  export EDITOR="vim"
  export VISUAL="vim"

'' + lib.optionalString (has "web") ''
  # Without SKIP_BROWSER_DOWNLOAD, `npm i playwright` re-downloads ~400MB and runs a browser nix doesn't know.
  # Behind the `web` bundle: the path alone pulls the browsers into the closure.
  export PLAYWRIGHT_BROWSERS_PATH="${pkgs.playwright-driver.browsers}"
  export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
'' + ''

  shell() {
      nix-shell '<nixpkgs>' -A "$1"
  }

  alias diff=difft

  alias ls='ls --color=auto'

  alias cld='claude --dangerously-skip-permissions'
'' + lib.optionalString (pkgs.stdenv.hostPlatform.isDarwin && has "containers")
  ("\n" + builtins.readFile ../darwin/scripts/colima-up.sh)
