{ config, pkgs, lib, user, identity, bundles, ... }:

let
  shared-programs = import ../shared/home-manager.nix { inherit config pkgs lib user identity bundles; };
in
{
  # ghostty 는 macOS 와 같은 모듈이다.
  imports = [ ../shared/ghostty ./nautice.nix ];

  home = {
    enableNixpkgsReleaseCheck = false;
    username = "${user}";
    homeDirectory = "/home/${user}";
    packages = (pkgs.callPackage ./packages.nix { inherit bundles; }) ++ [
      # subline 이 gsettings 로 고르는 테마(crates/compositor/src/accent.rs). GTK 3 에는 color-scheme 이 없어
      # 다크 모드가 Adwaita-dark 라는 테마 이름으로 간다 — 이 패키지가 없으면 GTK 3 앱만 밝게 남는다.
      pkgs.adwaita-icon-theme
      pkgs.gnome-themes-extra  # Adwaita-dark
    ];
    # mkDefault: 옛 릴리스로 설치한 호스트가 자기 값을 고정한다. 그 호스트의 system.stateVersion 과 맞춘다.
    stateVersion = lib.mkDefault "26.11";

    # 실패를 경고로만 다루는 이유는 조각 머리말에 있다(darwin 과 공용).
    activation.miseInstall = import ../shared/mise-install.nix { inherit pkgs lib config; };
    activation.claudeAttribution = import ../shared/claude-attribution.nix { inherit pkgs lib; };
  };

  programs = shared-programs;
}
