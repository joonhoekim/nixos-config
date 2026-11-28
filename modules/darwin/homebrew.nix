{ config, user, nix-homebrew, homebrew-core, homebrew-cask, homebrew-bundle, ... }:

# brew 본체와 탭은 nix-homebrew 가 flake input 으로 고정한다. 무엇을 까는지는 ./casks.nix 와 호스트의
# homebrew.brews 다. formula 는 nixpkgs(modules/shared/packages.nix)가 먼저고, 꼭 brew 여야 할 때만 brews.
{
  imports = [ nix-homebrew.darwinModules.nix-homebrew ];

  nix-homebrew = {
    inherit user;
    enable = true;
    taps = {
      "homebrew/homebrew-core" = homebrew-core;
      "homebrew/homebrew-cask" = homebrew-cask;
      "homebrew/homebrew-bundle" = homebrew-bundle;
    };
    # Allow imperative `brew tap`/`brew install` to coexist with Nix.
    mutableTaps = true;
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    # tap 이름을 Brewfile 에도 적는다 — 없으면 cleanup 을 켠 호스트에서 brew bundle 이 스토어 링크인
    # tap 을 untap 하려다 Permission denied 로 실패한다.
    taps = builtins.attrNames config.nix-homebrew.taps;
  };
}
