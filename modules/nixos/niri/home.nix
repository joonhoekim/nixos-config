{ lib, pkgs, niriShell, ... }:

# Home-manager half of the niri session: it generates
# ~/.config/niri/config.kdl and nothing else. Packaging, the GDM session entry
# and the shell's systemd unit are the NixOS module's job (./default.nix), so
# every knob here that would install something is switched off below.
#
# `niriShell` ("dms" | "noctalia") is threaded in from ./default.nix and only
# selects which shell-specific keybinds get written.
#
# Why the settings live in Nix rather than a hand-written config.kdl: the
# generated file is run through `niri validate` at *build* time, so a typo
# fails the rebuild instead of dropping you into a compositor with no keybinds.

let
  # ── Shell-specific bindings ────────────────────────────────────────────
  # Both shells expose the same surfaces (launcher, control centre, settings,
  # lock, volume/brightness OSD) under entirely different CLIs, so this is the
  # only part of the config that has to know which one is running.
  #
  # DMS speaks `dms ipc call <target> <function> [args]`; the target list is
  # `dms ipc` with the shell running (docs: danklinux.com/docs/dankmaterialshell/keybinds-ipc).
  shellBinds = {
    dms = {
      "Mod+Space".spawn = [ "dms" "ipc" "call" "spotlight" "toggle" ];
      "Mod+V".spawn = [ "dms" "ipc" "call" "clipboard" "toggle" ];
      "Mod+N".spawn = [ "dms" "ipc" "call" "notifications" "toggle" ];
      "Mod+S".spawn = [ "dms" "ipc" "call" "control-center" "toggle" ];
      "Mod+Comma".spawn = [ "dms" "ipc" "call" "settings" "toggle" ];
      "Mod+Escape".spawn = [ "dms" "ipc" "call" "powermenu" "toggle" ];
      "Mod+L".spawn = [ "dms" "ipc" "call" "lock" "lock" ];

      "XF86AudioRaiseVolume" = {
        _props.allow-when-locked = true;
        spawn = [ "dms" "ipc" "call" "audio" "increment" "5" ];
      };
      "XF86AudioLowerVolume" = {
        _props.allow-when-locked = true;
        spawn = [ "dms" "ipc" "call" "audio" "decrement" "5" ];
      };
      "XF86AudioMute" = {
        _props.allow-when-locked = true;
        spawn = [ "dms" "ipc" "call" "audio" "mute" ];
      };
      "XF86AudioMicMute" = {
        _props.allow-when-locked = true;
        spawn = [ "dms" "ipc" "call" "mic" "mute" ];
      };
      "XF86MonBrightnessUp" = {
        _props.allow-when-locked = true;
        spawn = [ "dms" "ipc" "call" "brightness" "increment" "5" ];
      };
      "XF86MonBrightnessDown" = {
        _props.allow-when-locked = true;
        spawn = [ "dms" "ipc" "call" "brightness" "decrement" "5" ];
      };
    };

    # Noctalia v5 speaks `noctalia msg <command> [args]` (v4's
    # `qs -c noctalia-shell ipc call ...` is gone). Only commands that appear in
    # the v5 docs are bound here — `noctalia msg --help` against a running shell
    # lists the rest, e.g. the notification centre, which has no documented
    # command yet and so is deliberately left unbound.
    noctalia = {
      "Mod+Space".spawn = [ "noctalia" "msg" "panel-toggle" "launcher" ];
      "Mod+S".spawn = [ "noctalia" "msg" "panel-toggle" "control-center" ];
      "Mod+Comma".spawn = [ "noctalia" "msg" "settings-toggle" ];
      "Alt+Tab".spawn = [ "noctalia" "msg" "window-switcher" ];
      "Mod+L".spawn = [ "noctalia" "msg" "session" "lock" ];

      "XF86AudioRaiseVolume" = {
        _props.allow-when-locked = true;
        spawn = [ "noctalia" "msg" "volume-up" ];
      };
      "XF86AudioLowerVolume" = {
        _props.allow-when-locked = true;
        spawn = [ "noctalia" "msg" "volume-down" ];
      };
      "XF86AudioMute" = {
        _props.allow-when-locked = true;
        spawn = [ "noctalia" "msg" "volume-mute" ];
      };
      "XF86MonBrightnessUp" = {
        _props.allow-when-locked = true;
        spawn = [ "noctalia" "msg" "brightness-up" ];
      };
      "XF86MonBrightnessDown" = {
        _props.allow-when-locked = true;
        spawn = [ "noctalia" "msg" "brightness-down" ];
      };
    };
  }.${niriShell};

  # Window rules the shell itself needs. Noctalia's own windows (settings,
  # pickers) are designed to float; DMS draws everything as layer-shell
  # surfaces, which niri never tiles, so it needs no rule.
  shellWindowRules = lib.optionals (niriShell == "noctalia") [
    {
      window-rule._children = [
        { match._props.app-id = "dev.noctalia.Noctalia"; }
        { open-floating = true; }
      ];
    }
  ];

  # ── Compositor bindings, shell-agnostic ────────────────────────────────
  commonBinds = {
    "Mod+Shift+Slash".show-hotkey-overlay = { };

    "Mod+Return" = {
      _props.hotkey-overlay-title = "Open a Terminal";
      # alacritty is the terminal this repo actually configures
      # (modules/shared/programs/alacritty.nix).
      spawn = [ "alacritty" ];
    };
    # Fallback launcher — see the fuzzel comment in ./default.nix. Mod+Space is
    # the shell's launcher; this one keeps working when the shell does not.
    "Mod+D".spawn = [ "fuzzel" ];

    "Mod+Q".close-window = { };

    # Focus / movement. Arrows and hjkl both, since the scrolling layout is
    # unfamiliar enough without also having to remember one set of keys.
    "Mod+Left".focus-column-left = { };
    "Mod+Right".focus-column-right = { };
    "Mod+Down".focus-window-down = { };
    "Mod+Up".focus-window-up = { };
    "Mod+H".focus-column-left = { };
    "Mod+L".focus-column-right = { };
    "Mod+J".focus-window-down = { };
    "Mod+K".focus-window-up = { };

    "Mod+Ctrl+Left".move-column-left = { };
    "Mod+Ctrl+Right".move-column-right = { };
    "Mod+Ctrl+Down".move-window-down = { };
    "Mod+Ctrl+Up".move-window-up = { };
    "Mod+Ctrl+H".move-column-left = { };
    "Mod+Ctrl+J".move-window-down = { };
    "Mod+Ctrl+K".move-window-up = { };

    "Mod+Home".focus-column-first = { };
    "Mod+End".focus-column-last = { };

    # Workspaces are vertical in niri; U/I sit under the right hand.
    "Mod+U".focus-workspace-down = { };
    "Mod+I".focus-workspace-up = { };
    "Mod+Ctrl+U".move-column-to-workspace-down = { };
    "Mod+Ctrl+I".move-column-to-workspace-up = { };
    "Mod+1".focus-workspace = 1;
    "Mod+2".focus-workspace = 2;
    "Mod+3".focus-workspace = 3;
    "Mod+4".focus-workspace = 4;
    "Mod+5".focus-workspace = 5;

    # Column sizing.
    "Mod+R".switch-preset-column-width = { };
    "Mod+F".maximize-column = { };
    "Mod+Shift+F".fullscreen-window = { };
    "Mod+C".center-column = { };
    "Mod+Minus".set-column-width = "-10%";
    "Mod+Equal".set-column-width = "+10%";
    "Mod+Shift+Space".toggle-window-floating = { };

    # Screenshots. `screenshot` opens niri's interactive UI; the other two are
    # immediate. Both shells also ship their own screenshot flows, but these
    # work with no shell running.
    "Print".screenshot = { };
    "Ctrl+Print".screenshot-screen = { };
    "Alt+Print".screenshot-window = { };

    # niri asks for confirmation before actually quitting.
    "Mod+Shift+E".quit = { };
  };
in
{
  wayland.windowManager.niri = {
    enable = true;

    # `package` stays set: it is what runs `niri validate` on the generated
    # config during the build (checkConfig defaults to package != null). The
    # duplicate install into the home profile is the same store path the system
    # profile already has.
    #
    # The remaining install-side knobs are nulled out so the NixOS module in
    # ./default.nix is the single owner of them — otherwise niri.service would
    # be written both to /etc/systemd/user and ~/.config/systemd/user, and
    # xdg.portal would be configured twice with only the NixOS one carrying the
    # per-desktop `config.niri` block that makes file pickers work.
    systemd.enable = false;
    portalPackage = null;
    xwaylandSatellitePackage = null;

    settings = {
      prefer-no-csd = { };

      # Client-side or not, screenshots land somewhere predictable.
      screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

      # Matches services.xserver.xkb.layout in hosts/nixos/common.nix. niri
      # reads its own xkb config rather than the X server's, so this is not
      # redundant — it is the only place the layout reaches a niri session.
      # Per-host remaps (Caps Lock -> Ctrl on galaxy-chromebook-1) are handled
      # below xkb by keyd, so they need no entry here.
      input = {
        keyboard.xkb.layout = "us";
        touchpad = {
          tap = { };
          natural-scroll = { };
          dwt = { }; # disable-while-typing
        };
        focus-follows-mouse = { };
      };

      layout = {
        gaps = 8;
        # Declaring the node is what turns the border on — niri disables it by
        # default and uses `border { off; }` to switch it back off, so there is
        # no `enable` here to write.
        border.width = 2;
        preset-column-widths._children = [
          { proportion = 0.33333; }
          { proportion = 0.5; }
          { proportion = 0.66667; }
        ];
        default-column-width.proportion = 0.5;
      };

      binds = commonBinds // shellBinds;

      # Repeated / parameterised top-level nodes. `_children` is home-manager's
      # toKDL escape hatch for nodes that can appear more than once, which a
      # plain attrset cannot express.
      _children = shellWindowRules ++ [
        # Wayland's xdg-activation is how a shell asks the compositor to focus
        # the window it just launched. Quickshell shells send it without a
        # valid input serial, so niri drops the request and the launcher's app
        # opens unfocused in the background. Both DMS and Noctalia document
        # this flag.
        { debug.honor-xdg-activation-with-invalid-serial = { }; }
      ];
    };
  };
}
