{ config, lib, pkgs, user, ... }:

# niri (scrollable-tiling Wayland compositor) as a second session alongside the
# GNOME one in hosts/nixos/common.nix, driven by a Quickshell-based desktop
# shell — DankMaterialShell (default) or Noctalia.
#
# tuigreet lists both sessions (see the greetd block in common.nix); niri is now
# the default one, and GNOME is the fallback a login can still be steered to
# when a shell bump breaks the desktop.
#
# Everything here comes from the pinned nixpkgs/home-manager — no extra flake
# input. That is worth stating because most guides still reach for
# sodiboo/niri-flake and the AvengeMedia/noctalia-dev flakes: home-manager
# absorbed `wayland.windowManager.niri` upstream, and nixpkgs now carries
# `programs.niri`, `programs.dms-shell` and `programs.noctalia`. The flakes only
# add declarative *shell* settings (see ./home.nix for why we don't need them).

let
  cfg = config.local.niri;
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

    shell = lib.mkOption {
      type = lib.types.enum [ "dms" "noctalia" ];
      default = "dms";
      example = "noctalia";
      description = ''
        Which desktop shell autostarts inside the niri session. Both are
        Quickshell shells covering the same ground (bar, launcher, control
        centre, notifications, lock), so exactly one runs at a time — they would
        otherwise fight over the org.freedesktop.Notifications bus name.

        Switching is this one line plus a rebuild; ./home.nix swaps the
        shell-specific keybinds to match. The unselected shell is NOT installed,
        so a comparison run means flipping this and rebuilding rather than
        keeping both on disk.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Adds niri to displayManager.sessionPackages (so GDM offers it), ships
      # niri.service for the user manager, and declares xdg.portal.config.niri
      # = gnome+gtk. That portal config is namespaced per desktop, which is why
      # it can coexist with the GNOME session's own portal setup untouched.
      programs.niri.enable = true;

      environment.systemPackages = with pkgs; [
        # niri starts this on demand when it is on $PATH — no spawn-at-startup
        # needed. Without it X11 clients simply have no display to connect to.
        xwayland-satellite

        # Deliberate fallback launcher, bound to Mod+D in ./home.nix while the
        # shell's own launcher sits on Mod+Space. If the shell fails to come up
        # (a beta bump, a bad setting) there is still a way to start a terminal
        # without dropping to a TTY.
        fuzzel
      ];

      home-manager.users.${user} = {
        imports = [ ./home.nix ];
        # The HM module lives in a separate arg scope (extraSpecialArgs in
        # flake.nix), so the shell choice is threaded in explicitly.
        _module.args.niriShell = cfg.shell;
      };
    }

    (lib.mkIf (cfg.shell == "dms") {
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
    })

    (lib.mkIf (cfg.shell == "noctalia") {
      programs.noctalia = {
        enable = true;

        # Same scoping problem, same fix — except the noctalia module builds the
        # unit itself, so `target` sets PartOf/After/WantedBy in one go.
        systemd = {
          enable = true;
          target = "niri.service";
        };

        # NetworkManager / bluetooth / UPower / power-profiles-daemon, all
        # mkDefault. common.nix already enables NetworkManager and
        # power-profiles-daemon; this only adds what its widgets read.
        recommendedServices.enable = true;
      };
    })
  ]);
}
