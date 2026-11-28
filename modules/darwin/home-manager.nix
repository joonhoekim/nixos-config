{ config, pkgs, lib, user, identity, bundles, ... }:

# home.file 항목은 여기 없다. macOS 쪽 설정 파일은 전부 ./rice 가 시드한다.
# 배선(useGlobalPkgs 등)은 ../../hosts/darwin/common.nix 에 있다.
{
  # NixOS 쪽 home-manager 도 같은 모듈을 쓴다(ghostty 자체는 ./casks.nix 가 cask 로 깐다).
  imports = [ ../shared/ghostty ];

  home = {
    enableNixpkgsReleaseCheck = false;
    packages = pkgs.callPackage ./packages.nix { inherit bundles; };
    # 호스트가 자기 값을 고정한다(hosts/darwin/<이름>/default.nix). 여기 값은 공용 .#<arch> 에만 쓰인다.
    stateVersion = lib.mkDefault "23.11";

    activation.miseInstall = import ../shared/mise-install.nix { inherit pkgs lib config; };
    activation.claudeAttribution = import ../shared/claude-attribution.nix { inherit pkgs lib; };
  };

  programs = import ../shared/home-manager.nix { inherit config pkgs lib user identity bundles; };
}
