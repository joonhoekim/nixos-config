{ config, pkgs, lib, user, ... }:

let
  shared-programs = import ../shared/home-manager.nix { inherit config pkgs lib user; };
in
{
  # 터미널 라이싱(셰이더 포함)을 $HOME 에 심는다. macOS 쪽 home-manager 도 같은
  # 모듈을 import 한다 — 관리 지점이 하나여야 해서 니리 밑이 아니라 shared 에 둔다.
  # 여기서 import 하는 것도 그래서다: 니리를 안 쓰는(GNOME 만 쓰는) 머신에서도
  # 터미널은 똑같이 필요하다.
  imports = [ ../shared/ghostty ];

  home = {
    enableNixpkgsReleaseCheck = false;
    username = "${user}";
    homeDirectory = "/home/${user}";
    packages = (pkgs.callPackage ./packages.nix {}) ++ [
      # GTK themes. Nothing in this repo *configures* GTK any more (see the
      # note where `gtk.enable` used to be) — DMS writes the config files and
      # needs these to exist to name them.
      pkgs.adwaita-icon-theme  # "Adwaita" icons; adapts to a dark GTK theme
      pkgs.gnome-themes-extra  # provides the Adwaita-dark GTK theme
    ];
    # mkDefault so a host installed at an older release can pin its own (see
    # hosts/nixos/galaxy-chromebook-1). Keep this in sync with the host's
    # system.stateVersion.
    stateVersion = lib.mkDefault "26.11";

    # mise 도구 설치. 왜 실패를 경고로만 다루는지까지 조각 머리말에 있다 —
    # darwin 과 같은 것을 쓴다.
    activation.miseInstall = import ../shared/mise-install.nix { inherit pkgs lib config; };
  };

  # Dark mode. GNOME reads the dconf keys below; the `gtk` block writes
  # ~/.config/gtk-{3,4}.0/settings.ini, which covers GTK apps launched
  # outside a GNOME session (and Xwayland ones that ignore the portal).
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
  };

  # `gtk.enable` used to live here. It was removed because DankMaterialShell
  # writes the very same files and wins the race half the time:
  #
  #   scripts/gtk.sh          `sed -i` on ~/.config/gtk-4.0/gtk.css, which
  #                           REPLACES a home-manager symlink with a real file,
  #                           and `rm`s a symlinked gtk-3.0/gtk.css outright
  #   SettingsData.qml:1605   creates gtk-{3,4}.0/settings.ini when absent, to
  #                           put its icon theme there
  #
  # DMS does skip a settings.ini it cannot write (`[ ! -w ] && continue`), so a
  # machine whose links are already in place survives — which is why mn56 never
  # noticed. galaxy-chromebook-1 lost the race once, ended up with four real
  # files, and every rebuild after that failed with "would be clobbered".
  #
  # Handing GTK to DMS is also the consistent choice: the shell already owns
  # the palette for niri, ghostty and fuzzel, and its gtk-3.0/dank-colors.css
  # is what makes GTK apps follow the wallpaper. The themes themselves are
  # still installed from Nix (see home.packages above) so there is something
  # for DMS to point at.

  programs = shared-programs;
}
