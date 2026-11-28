{ user, ... }:

# MacBook Pro 14" (M4 Pro). 주로 개발하는 기계라 묶음과 cask 는 기본값(전부)을 쓴다.
# localHostName 은 이 디렉토리 이름에서 온다(flake.nix 의 mkDarwinHost).

{
  imports = [ ../common.nix ];

  # 이 기계가 처음 활성화된 값. 상태 호환성을 고정하므로 올리지 않는다.
  system.stateVersion = 5;
  home-manager.users.${user}.home.stateVersion = "23.11";

  # nixpkgs 의 mole 은 이름만 같은 SSH 터널 도구(davrodpin/mole)라 brew 로 받는다.
  homebrew.brews = [ "mole" ];

  # homebrew.onActivation.cleanup 을 켜지 않는다: 선언 밖에서 brew 로 깐 cask·formula 가 activation 때 지워진다.
  # 켜기 전에 `brew list --cask` · `brew leaves` 를 선언과 맞춘다.
}
