# The pointer half of the Caps Lock layer: a daemon that turns the sentinel
# keys keyd emits (F13-F21) into pointer motion, wheel clicks and buttons.
#
# Why it is a separate process at all is argued in ./pointerd.py and in the
# header of ../keyboard.nix — the short version is that keyd can press mouse
# buttons but cannot move a pointer, and nothing in nixpkgs does mouse keys
# on Wayland the way this layer wants them (held trigger, diagonals,
# acceleration, Shift for fine aim).
#
# Imported by hosts/nixos/common.nix.
{ pkgs, ... }:

let
  python = pkgs.python3.withPackages (ps: [ ps.evdev ]);
in
{
  systemd.services.pointerd = {
    description = "Pointer motion for the Caps Lock layer";

    # keyd's virtual keyboard is the input. `after` only orders the initial
    # start; the daemon waits for the device itself and reconnects when keyd
    # is restarted, so a missing keyd is a pause rather than a failure.
    after = [ "keyd.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      # Root: it reads /dev/input and creates a uinput device. uinput is
      # already in boot.kernelModules for keyd's sake (hosts/nixos/common.nix).
      ExecStart = "${python}/bin/python3 ${./pointerd.py}";
      Restart = "always";
      RestartSec = 2;
      # A pointer that is nudged 125 times a second should never be the
      # reason something else stutters.
      Nice = -5;
    };
  };
}
