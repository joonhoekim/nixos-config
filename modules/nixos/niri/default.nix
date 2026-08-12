{ config, lib, pkgs, user, ... }:

# niri (scrollable-tiling Wayland compositor) as a second session alongside the
# GNOME one in hosts/nixos/common.nix, driven by DankMaterialShell — a
# Quickshell-based desktop shell providing the bar, launcher, control centre,
# notifications and lock screen.
#
# tuigreet lists both sessions (see the greetd block in common.nix); niri is now
# the default one, and GNOME is the fallback a login can still be steered to
# when a shell bump breaks the desktop.
#
# Everything here comes from the pinned nixpkgs/home-manager — no extra flake
# input. That is worth stating because most guides still reach for
# sodiboo/niri-flake: nixpkgs carries `programs.niri` and `programs.dms-shell`,
# and the flake only adds declarative *shell* settings, which this module
# deliberately does not want (see the seeding block below).
#
# ── Installation is declarative, ricing is not ─────────────────────────────
# This module installs and wires the session. It does NOT own the compositor or
# shell *settings*. Those live as ordinary writable files in $HOME:
#
#   ~/.config/niri/config.kdl            niri, hot-reloaded on save
#   ~/.config/DankMaterialShell/         DMS, written by its own settings GUI
#   ~/.config/ghostty/config             terminal
#
# home-manager's `wayland.windowManager.niri.settings` used to generate the
# first of those. It was dropped on purpose: it makes config.kdl a read-only
# store symlink, so every keybind tweak costs a full rebuild, and DMS — which
# appends its own `include` lines to config.kdl from several settings tabs —
# silently fails against a read-only target.
#
# ./rice/ holds what a fresh machine needs to start from, seeded into $HOME only
# when the file is missing. Round-trip it with `apps/rice-save`. What is NOT in
# there is DMS's settings.json: it is 21KB of GUI state, and the look it encodes
# is already captured by ./rice/profiles/*/dms.json, which apps/rice-switch
# merges onto whatever defaults DMS writes for itself on first run.

let
  cfg = config.local.niri;

  # Which of ./rice/profiles/* a machine with no config yet starts on. This is
  # only a seed — apps/rice-switch owns the choice from the first switch on, and
  # nothing re-reads this value afterwards. Not an option because a NixOS option
  # would imply the profile is declarative, which is the opposite of the point.
  seedProfile = "amoled";
in
{
  options.local.niri = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install the niri session. On by default because hosts/nixos/common.nix
        imports this for every host; set to false on a machine that should stay
        GNOME-only.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Adds niri to displayManager.sessionPackages (so the greeter offers it), ships
    # niri.service for the user manager, and declares xdg.portal.config.niri
    # = gnome+gtk. That portal config is namespaced per desktop, which is why
    # it can coexist with the GNOME session's own portal setup untouched.
    programs.niri.enable = true;

    environment.systemPackages = with pkgs; [
      # niri starts this on demand when it is on $PATH — no spawn-at-startup
      # needed. Without it X11 clients simply have no display to connect to.
      xwayland-satellite

      # Deliberate fallback launcher, bound to Mod+D in ./rice/config.kdl while the
      # shell's own launcher sits on Mod+Space. If the shell fails to come up
      # (a beta bump, a bad setting) there is still a way to start a terminal
      # without dropping to a TTY.
      fuzzel
    ];

    # Seed the ricing files on a machine that has none yet. Deliberately not
    # home.file / xdg.configFile: those symlink the store and make the target
    # read-only, which is exactly what this module is avoiding — niri could no
    # longer be tuned without a rebuild, and DMS's settings GUI writes
    # atomically (temp file + rename, see Common/SettingsData.qml), so a
    # symlink there would be replaced by a regular file on its first save.
    #
    # `[ -e ]` guards every copy: an existing config is never touched, so a
    # rebuild mid-ricing cannot clobber unsaved work. Snapshot the other
    # direction with apps/rice-save.
    #
    # Runs after linkGeneration because on the machine this module was written
    # for, config.kdl is still the home-manager symlink from the previous
    # generation; the copy has to land after home-manager removes it.
    # Written as a module function so `lib` here is home-manager's — `lib.hm`
    # does not exist in the NixOS module scope this file otherwise evaluates
    # in.
    home-manager.users.${user} = { lib, ... }: {
      home.activation.seedNiriRice = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        ${import ../../shared/rice-seed-helpers.nix}

        seed ${./rice/config.kdl} "$HOME/.config/niri/config.kdl"

        # 밝기 키의 인자 개수를 고친다. 사연과 idempotent 인 이유는 ../hyprland
        # 쪽 같은 자리에 적어 뒀다 — 두 세션이 같은 DMS 를 같은 방식으로 잘못
        # 부르고 있었고, 고친 줄은 시드에만 넣어서는 이미 config.kdl 을 가진
        # 머신에 닿지 않는다.
        if [ -f "$HOME/.config/niri/config.kdl" ]; then
          $DRY_RUN_CMD ${pkgs.gnused}/bin/sed -i -E \
            's#("dms" "ipc" "call" "brightness" "(increment|decrement)" "[0-9]+");#\1 "";#g' \
            "$HOME/.config/niri/config.kdl"
        fi

        # config.kdl 이 optional 로 include 하는 조각. 창 열림/닫힘 셰이더가
        # 들어 있고, 지우면 니리 기본 애니메이션으로 돌아간다.
        seed ${./rice/animations.kdl} "$HOME/.config/niri/animations.kdl"
        ensure "$HOME/.config/niri/config.kdl" 'include "animations.kdl" optional=true' \
          '// 창 열림/닫힘 셰이더. 파일을 지우면 니리 기본 애니메이션으로 돌아간다.'

        # Look profiles, swapped live by apps/rice-switch.
        seed ${./rice/profiles} "$HOME/.config/rice/profiles"

        # ...and the pieces the seeded profile is made of, so a fresh machine
        # boots into a coherent look instead of a half-applied one. Only the
        # starting point: rice-switch overwrites them from then on, and the
        # guard means it never re-seeds over a switch you made.
        seed ${./rice/profiles/${seedProfile}/niri.kdl} "$HOME/.config/niri/profile.kdl"
        seed ${pkgs.writeText "rice-current" seedProfile} "$HOME/.config/rice/current"

        # 터미널(ghostty)은 여기 없다. ../../shared/ghostty 가 심고, 그
        # 모듈은 macOS 에서도 같은 파일을 쓴다 — 셰이더는 플랫폼을 안 가리고
        # 니리는 리눅스 전용이라, 터미널 룩을 니리 밑에 두면 macOS 가 같은 것을
        # 쓰려 할 때 경로부터 막힌다.
        #
        # 색이 프로필을 따라오는 건 그쪽에서도 그대로다. ghostty 가
        # `theme = dankcolors` 로 읽는 파일을 matugen 이 월페이퍼·테마가 바뀔
        # 때마다 다시 쓰기 때문이고(matugenTemplateGhostty), 이 레포는 그 외에
        # 터미널 색을 어디서도 선언하지 않는다.

        # fuzzel 은 형태(폰트/여백/줄높이)만 레포에 두고, 색과 화면에 맞춰
        # 계산되는 lines/radius 는 apps/rice-fuzzel 이 dank-rice.ini 에 쓴다.
        # include 줄은 여기서 붙여 내보낸다. 레포 파일에 넣어둘 수 없는 건
        # fuzzel 이 절대 경로만 받기 때문인데, 홈 경로는 이 모듈이 알고 있다.
        # rice-fuzzel 도 같은 줄을 붙일 줄 알지만, 그건 손으로 만든 설정을 위한
        # 안전망이고 — 첫 로그인에 런처가 fuzzel 기본 테마(솔라라이즈드 라이트)로
        # 뜨지 않으려면 이 시점에 이미 배선돼 있어야 한다.
        seed ${pkgs.writeText "fuzzel.ini" (''
          # apps/rice-fuzzel 이 쓰는 색 파일. 기본 섹션이어야 해서 맨 위다.
          include=/home/${user}/.config/fuzzel/dank-rice.ini

        '' + builtins.readFile ./rice/fuzzel.ini)} "$HOME/.config/fuzzel/fuzzel.ini"
        seed ${./rice/fuzzel-fallback.ini} "$HOME/.config/fuzzel/dank-rice.ini"

        # GTK. Seeded rather than home-manager-managed because DMS edits these
        # in place — see the header of rice/gtk-settings.ini for the whole
        # story. Both toolkits read the same keys, so one file serves both.
        # This is a *niri* need, not a GNOME one: there is no settings daemon
        # here to broadcast XSettings, so GTK apps read the file directly.
        # apps/rice-save takes gtk-3.0 back as the canonical one.
        seed ${./rice/gtk-settings.ini} "$HOME/.config/gtk-3.0/settings.ini"
        seed ${./rice/gtk-settings.ini} "$HOME/.config/gtk-4.0/settings.ini"
      '';
    };

    programs.dms-shell = {
      enable = true;

      # dms.service ships `[Install] WantedBy=graphical-session.target`, which
      # would start DMS inside the *GNOME* session too. NixOS ignores a
      # package unit's own [Install] section and only writes the .wants
      # symlink named by this option, so pointing it at niri.service scopes
      # the shell to the niri session. Verified against the built system:
      # etc/systemd/user/niri.service.wants/dms.service exists and no
      # graphical-session.target.wants entry does.
      systemd.target = "niri.service";
    };
  };
}
