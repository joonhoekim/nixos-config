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
    # after that argument (uwsm's own example-units file spells this exact
    # target out). Confirm on the machine with:
    #   systemctl --user list-units 'wayland-session@*'
    systemd.user.services = lib.mkIf config.programs.dms-shell.enable {
      dms.wantedBy = [ "wayland-session@hyprland.desktop.target" ];
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

        # 터미널·런처·GTK 는 여기서 심지 않는다. ../niri 와 ../../shared/ghostty.nix
        # 가 이미 같은 파일을 $HOME 에 깔아 두고, 그것들은 컴포지터를 안 가린다.
      '';
    };
  };
}
