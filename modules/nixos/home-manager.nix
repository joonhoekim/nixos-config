{ config, pkgs, lib, user, identity, bundles, ... }:

let
  shared-programs = import ../shared/home-manager.nix { inherit config pkgs lib user identity bundles; };
in
{
  # ghostty 는 macOS 와 같은 모듈이고, GNOME 만 쓰는 머신에도 필요해 니리 밑이 아니라 여기서 import 한다.
  imports = [ ../shared/ghostty ./nautice.nix ];

  home = {
    enableNixpkgsReleaseCheck = false;
    username = "${user}";
    homeDirectory = "/home/${user}";
    packages = (pkgs.callPackage ./packages.nix { inherit bundles; }) ++ [
      # GTK 설정 파일은 DMS 가 쓴다(gtk.enable 을 안 쓰는 이유: docs/niri.md). 여기는 DMS 가 가리킬 테마만 깐다.
      pkgs.adwaita-icon-theme
      pkgs.gnome-themes-extra  # Adwaita-dark
    ];
    # mkDefault: 옛 릴리스로 설치한 호스트가 자기 값을 고정한다. 그 호스트의 system.stateVersion 과 맞춘다.
    stateVersion = lib.mkDefault "26.11";

    # 실패를 경고로만 다루는 이유는 조각 머리말에 있다(darwin 과 공용).
    activation.miseInstall = import ../shared/mise-install.nix { inherit pkgs lib config; };
    activation.claudeAttribution = import ../shared/claude-attribution.nix { inherit pkgs lib; };
  };

  # GNOME 세션의 다크 모드. GNOME 밖의 GTK 는 DMS 가 쓰는 settings.ini 를 읽는다.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
  };

  # gtk.enable 은 두지 않는다. DMS 가 같은 파일을 고쳐(scripts/gtk.sh, SettingsData.qml) 심링크를 실파일로
  # 바꾸고, 그 뒤 rebuild 가 "would be clobbered" 로 멈춘다. GTK 는 DMS 가 소유한다.

  programs = shared-programs;
}
