{ config, lib, pkgs, user, ... }:

# Hyprland as a third session alongside niri and GNOME, sharing the same
# DankMaterialShell that the niri session runs.
#
# Why a second tiling compositor at all: niri has no output-wide shader hook —
# custom shaders exist only inside window-open/close/resize animations, and
# long-running ones are still an open request upstream (niri #913). Hyprland has
# `decoration:screen_shader`, a fragment shader applied at the end of rendering
# — an output-wide CRT is a one-line setting there and impossible here.
#
# Everything comes from the pinned nixpkgs — no hyprland flake input. That is
# worth stating because most guides still reach for it: nixpkgs carries 0.56,
# which is well past the 0.55 Lua switch, and the upstream flake only starts
# paying for itself once hyprpm plugins need a version-matched compositor.
#
# ── Sessions ───────────────────────────────────────────────────────────────
# programs.hyprland.enable puts *two* entries in the greeter, because the
# package's passthru.providedSessions carries both: "Hyprland" (plain) and
# "Hyprland (uwsm-managed)". Use the uwsm one — it is what wires the shell up
# (see the systemd block below). The plain entry stays as a fallback for when
# uwsm itself is what broke; DMS does not autostart there.
#
# niri remains services.displayManager.defaultSession; tuigreet's
# --remember-session is what actually decides where a login lands.
#
# ── The shader ─────────────────────────────────────────────────────────────
# ./rice/shaders holds two ports of the terminal's CRT (see
# modules/shared/ghostty/shaders/crt.glsl), and Mod+Shift+C cycles off → static
# → animated. Two files rather than one because Hyprland cannot damage-track a
# shader that reads `time`: the animated one only works with
# debug:damage_tracking = 0, which redraws the whole screen every frame. The
# keybind moves both settings together; the static one leaves damage tracking
# alone and costs nothing on an idle screen.
#
# ── Installation is declarative, ricing is not ─────────────────────────────
# Same split as ../niri: this module installs and wires the session, and the
# *settings* live as ordinary writable files under $HOME, seeded from ./rice
# only when missing. Hyprland hot-reloads hyprland.lua on save, and DMS writes
# its own fragments into ~/.config/hypr/dms/ — neither survives a store symlink.

let
  cfg = config.local.hyprland;
in
{
  options.local.hyprland = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install the Hyprland session. On by default because
        hosts/nixos/common.nix imports this for every host; set to false on a
        machine that should offer niri and GNOME only.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;

      # uwsm (Universal Wayland Session Manager) wraps the compositor in systemd
      # units: it starts graphical-session.target, runs XDG autostart, binds the
      # session to the login session and shuts it down in order. Hyprland's own
      # systemd story is thinner than niri's — 0.56 does not even ship a
      # hyprland-session.target any more (the wiki has you hand-write one), and
      # upstream points at uwsm instead.
      #
      # This only flips programs.uwsm.enable. The session entry it is used from
      # comes from the hyprland package itself, not from
      # programs.uwsm.waylandCompositors — that option is for compositors whose
      # package ships no uwsm desktop entry.
      withUWSM = true;
    };

    environment.systemPackages = with pkgs; [
      # niri screenshots itself; hyprland does not. hyprshot wraps grim/slurp
      # and knows how to ask hyprctl for the active window's geometry, which is
      # the one mode a bare `grim -g "$(slurp)"` cannot do.
      hyprshot
    ];

    # Start DMS in this session too.
    #
    # nixpkgs' dms module writes `wantedBy = [ cfg.systemd.target ]` — a list —
    # so adding to it here leaves ../niri's `systemd.target = "niri.service"`
    # alone rather than fighting over a single string option. The unit is still
    # not wanted by graphical-session.target, so it stays out of GNOME.
    #
    # The instance name is the compositor's desktop entry ID: the entry runs
    # `uwsm start -e -D Hyprland hyprland.desktop`, and uwsm names its units
    # after that argument. Confirm on the machine with:
    #   systemctl --user list-units 'wayland-wm@*'
    #
    # ── 왜 wayland-session@….target 이 아니라 wayland-wm@….service 인가 ──────
    # 저 target 에 걸면 DMS 는 영영 안 뜬다. 세션 로그에 그대로 나온다:
    #
    #   wayland-session@hyprland.desktop.target: Found ordering cycle:
    #     dms.service/start after graphical-session.target/verify-active
    #     after wayland-session@hyprland.desktop.target/start - after dms.service
    #   Job dms.service/start deleted to break ordering cycle
    #
    # 고리의 세 변은 이렇다:
    #
    #   1. target 은 자기가 Wants 하는 유닛에 암묵적으로 After 를 붙인다. 서비스와
    #      달리 target 만의 기본 동작이다(systemd.target(5) — DefaultDependencies
    #      가 no 가 아니면 Wants/Requires 를 After 로 보강한다). 그래서
    #      wantedBy 를 걸어 준 순간 target 이 dms.service 뒤로 밀린다.
    #   2. dms.service 는 자기 유닛에 After=graphical-session.target 을 들고 있다.
    #   3. uwsm 의 wayland-session@.target 은 Before=graphical-session.target 이다.
    #
    # systemd 는 고리를 끊으려고 셋 중 하나를 지우는데, 하필 dms.service 의 시작
    # 작업을 지운다. 그래서 "에러도 없고 유닛은 enabled 인데 화면에 셸이 없는"
    # 상태가 된다.
    #
    # wayland-wm@….service 는 서비스라 1 번 규칙이 없다 — 고리가 안 생긴다.
    # 순서도 맞는다: 저 서비스가 dms 를 끌어오고, dms 는 자기 After 대로
    # graphical-session.target 이 올라온 뒤에 뜬다. ../niri 가 niri.service 에
    # 거는 것과 같은 모양이고, 이쪽이 우연이 아니라 이유가 있었던 셈이다.
    #
    # 종료는 이 줄과 무관하다. dms.service 의 PartOf=graphical-session.target 이
    # 이미 로그아웃 때 같이 내린다.
    systemd.user.services = lib.mkIf config.programs.dms-shell.enable {
      dms.wantedBy = [ "wayland-wm@hyprland.desktop.service" ];
    };

    # Seed the ricing files on a machine that has none yet. Same rules as
    # ../niri: `[ -e ]` guards every copy, so an existing config is never
    # touched and a rebuild mid-ricing cannot clobber unsaved work.
    home-manager.users.${user} = { lib, ... }: {
      home.activation.seedHyprlandRice = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        ${import ../../shared/rice-seed-helpers.nix}

        seed ${./rice/hyprland.lua} "$HOME/.config/hypr/hyprland.lua"

        # DMS 가 자기 설정을 쓰는 자리. 빈 조각을 미리 깔아 두는 건 DMS 가 처음
        # 뜨기 전에도 hyprland.lua 의 require 가 뭔가를 찾게 하려는 것이다.
        # (require 자체는 pcall 로 감싸 뒀으니 없어도 세션은 뜬다.)
        seed ${./rice/dms} "$HOME/.config/hypr/dms"

        # 화면 셰이더. hyprland.lua 의 Mod+Shift+C 가 절대 경로로 집어 든다 —
        # decoration:screen_shader 는 경로만 받고 ~ 를 풀지 않는다.
        seed ${./rice/shaders} "$HOME/.config/hypr/shaders"

        # 터미널·런처·GTK 는 여기서 심지 않는다. ../niri 와 ../../shared/ghostty.nix
        # 가 이미 같은 파일을 $HOME 에 깔아 두고, 그것들은 컴포지터를 안 가린다.
      '';
    };
  };
}
