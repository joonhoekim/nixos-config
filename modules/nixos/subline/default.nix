{ config, lib, pkgs, subline, ... }:

# subline — the touch-first Wayland compositor from ~/git/subline — as the
# default session of every NixOS host here, and as greetd's login screen.
#
# subline ships its own NixOS module (nix/module.nix in that repo; the flake
# input is `subline` in flake.nix). That module does the session plumbing:
# the package and xwayland-satellite, the wayland-sessions entry, the portal
# choice (gtk + gnome-keyring + wlr for screenshots/screen share + subline's
# own), a mate-polkit agent unit that only runs under XDG_CURRENT_DESKTOP=subline,
# the PAM service the lock screen checks passwords through, and — with
# `greeter` — greetd itself (command, no text-greeter TTY handling, a home where
# the greeter remembers the last user and session). This file only turns it on
# and settles what is *this repo's* to decide: which session is the default and
# which greeter is the fallback.
#
# ── Updating ──────────────────────────────────────────────────────────────
# `nix run .#subline-update` (apps/subline-update): bumps the input, switches,
# restarts the live session in place into the new build and commits flake.lock.
# The login screen is the new build the next time it comes up.
#
# ── Sessions: subline is the default, nothing else is removed ─────────────
# subline is under development, so every other session stays installed and
# the login screen keeps offering them: Hyprland (uwsm-managed), niri, GNOME.
# subline's greeter lists every wayland-sessions entry of
# services.displayManager.sessionData.desktops and remembers the last user and
# session picked, so going back to Hyprland is one tap at login and sticks from
# then on. Nothing about those sessions changes — ../hyprland and ../niri still
# start DMS in their own session; subline's session does not start DMS. subline
# brings its own strip, dock, on-screen keyboard, notifications and lock screen,
# and two notification daemons on one bus fight over the name.
#
# ── If the login screen itself does not come up ───────────────────────────
# greetd's unit is Restart=on-success, so a greeter that crashes leaves VT1
# dark rather than looping. Ctrl+Alt+F2 gives a text login; from there either
#   local.subline.greeter = false;   # tuigreet is back at the next rebuild
# or `nix run .#rollback`, or pick the previous generation in the boot menu.
#
# ── Config is the user's, not Nix's ──────────────────────────────────────
# subline reads ~/.config/subline/config.toml and hot-reloads it; the settings
# app (subline-settings) writes it. Nothing is seeded from this repo yet —
# unlike ../niri and ../hyprland there is no rice/ here. If a seed is ever
# wanted it goes through rice_sync like the others.

let
  cfg = config.local.subline;
in
{
  imports = [ subline.nixosModules.default ];

  options.local.subline = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install the subline session and make it the default one. On by default
        because hosts/nixos/common.nix imports this for every host; set to
        false on a machine that should keep niri as the default and offer no
        subline entry.
      '';
    };
    greeter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Draw greetd's login screen with subline (`subline --greeter`) instead
        of tuigreet. The session list is the same either way; this only changes
        the greeter in front of it. Turn off to get tuigreet back without
        touching the sessions.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.subline = {
      enable = true;
      greeter = cfg.greeter;
    };

    # hosts/nixos/common.nix says niri with mkDefault; this wins while subline
    # is installed. The value has to be one of sessionData.sessionNames, and
    # "subline" is there through the package's passthru.providedSessions.
    services.displayManager.defaultSession = "subline";
  };
}
