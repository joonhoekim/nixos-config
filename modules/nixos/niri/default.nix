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
# sodiboo/niri-flake and the AvengeMedia/noctalia-dev flakes: nixpkgs carries
# `programs.niri`, `programs.dms-shell` and `programs.noctalia`, and the flakes
# only add declarative *shell* settings, which this module deliberately does not
# want (see the seeding block below).
#
# ── Installation is declarative, ricing is not ─────────────────────────────
# This module installs and wires the session. It does NOT own the compositor or
# shell *settings*. Those live as ordinary writable files in $HOME:
#
#   ~/.config/niri/config.kdl            niri, hot-reloaded on save
#   ~/.config/DankMaterialShell/         DMS, written by its own settings GUI
#
# home-manager's `wayland.windowManager.niri.settings` used to generate the
# first of those. It was dropped on purpose: it makes config.kdl a read-only
# store symlink, so every keybind tweak costs a full rebuild, and DMS — which
# appends its own `include` lines to config.kdl from several settings tabs —
# silently fails against a read-only target.
#
# ./rice/ holds a snapshot of both, seeded into $HOME only when the file is
# missing. Round-trip it with `apps/rice-save`. Once the ricing settles, moving
# rice/config.kdl back into Nix is a mechanical change; DMS's 21KB settings.json
# is GUI state and is not worth declaring either way.

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

    shell = lib.mkOption {
      type = lib.types.enum [ "dms" "noctalia" ];
      default = "dms";
      example = "noctalia";
      description = ''
        Which desktop shell autostarts inside the niri session. Both are
        Quickshell shells covering the same ground (bar, launcher, control
        centre, notifications, lock), so exactly one runs at a time — they would
        otherwise fight over the org.freedesktop.Notifications bus name.

        Switching is this one line plus a rebuild. The unselected shell is NOT
        installed, so a comparison run means flipping this and rebuilding rather
        than keeping both on disk. The shell-specific keybinds are no longer
        swapped for you — ./rice/config.kdl carries the DMS ones, so a switch to
        noctalia means rewriting those binds by hand in ~/.config/niri.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Adds niri to displayManager.sessionPackages (so the greeter offers it), ships
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
          seed() { # seed <store-source> <destination>
            [ -e "$2" ] && return 0
            $DRY_RUN_CMD mkdir -p "$(dirname "$2")"
            $DRY_RUN_CMD cp -rT "$1" "$2"
            # Store paths are read-only; the whole point is a writable copy.
            $DRY_RUN_CMD chmod -R u+w "$2"
            echo "seeded $2"
          }
          seed ${./rice/config.kdl} "$HOME/.config/niri/config.kdl"
          seed ${./rice/dms/settings.json} "$HOME/.config/DankMaterialShell/settings.json"
          seed ${./rice/dms/themes} "$HOME/.config/DankMaterialShell/themes"

          # Look profiles, swapped live by apps/rice-switch.
          seed ${./rice/profiles} "$HOME/.config/rice/profiles"

          # ...and the pieces the seeded profile is made of, so a fresh machine
          # boots into a coherent look instead of a half-applied one. Only the
          # starting point: rice-switch overwrites all three from then on, and
          # the guard means it never re-seeds over a switch you made.
          seed ${./rice/profiles/${seedProfile}/niri.kdl} "$HOME/.config/niri/profile.kdl"
          seed ${./rice/profiles/${seedProfile}/alacritty.toml} "$HOME/.config/alacritty/rice.toml"
          seed ${pkgs.writeText "rice-current" seedProfile} "$HOME/.config/rice/current"
        '';
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
