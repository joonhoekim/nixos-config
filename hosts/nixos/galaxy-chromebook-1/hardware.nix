{ pkgs, ... }:

# 이 섀시만의 사정. Intel 공통은 modules/nixos/intel.nix. 전체 그림: docs/galaxy-chromebook-1.md

{
  hardware.firmware = with pkgs; [
    # Sound Open Firmware — the DSP audio codec stays silent without it.
    sof-firmware

    # EDID candidates for `display-try`. Kernels ship no generic blobs (the loader finds
    # nothing in /lib/firmware/edid/ and fails -2), so we build them; results per blob in
    # docs/galaxy-chromebook-1.md. clean = true: only these modelines, named as the .bin.
    (edid-generator.overrideAttrs (_: {
      clean = true;
      modelines = ''
        Modeline "1920x1080" 148.50 1920 2008 2052 2200 1080 1084 1089 1125 +hsync +vsync
        Modeline "1920x1080rb" 138.50 1920 1968 2000 2080 1080 1083 1088 1111 +hsync -vsync
      '';
    }))

    # Panel-derived: the real vendor block keeps it a digital DP sink at 10bpc, where
    # edid-generator's template says analog. Uncompressed: display-try wants plain .bin.
    (runCommand "edid-panel-fhd" {
      nativeBuildInputs = [ python3 ];
      passthru.compressFirmware = false;
    } ''
      install -d "$out/lib/firmware/edid"
      python3 ${./edid/make-panel-fhd.py} \
        ${./edid/panel-native.hex} "$out/lib/firmware/edid/panelfhd.bin" 1
      python3 ${./edid/make-panel-fhd.py} \
        ${./edid/panel-native.hex} "$out/lib/firmware/edid/panelfhd2.bin" 2
    '')
  ];

  # The stylus (WCOM006C:00 2D1F:009D) needs no extra module: hid-generic gives pressure
  # (0-4095), tilt (±60°) and the tip. `wacom` only claims vendor 056A, so it never binds here.

  # i915 lists no eDP mode but the panel's fixed 3840x2160, so FHD needs this patch
  # (why it suffices: its header). Costs a full local kernel build on every bump.
  boot.kernelPatches = [{
    name = "i915-edp-scaled-modes";
    patch = ./kernel/i915-edp-scaled-modes.patch;
  }];

  # Adds a mode and keeps 3840x2160 preferred. Make 1080p preferred and i915 sends 1080p
  # timing to the 4K panel, which stays dark. Black screen: boot the previous generation.
  # Why not an EDID or debugfs override: docs/galaxy-chromebook-1.md
  boot.kernelParams = [ "video=eDP-1:1920x1080@60" ];

  # 이 개체의 터치패드는 팬텀 터치가 나서 `touchpad off` 가 있다. 부팅부터 끄려면 udev 에
  # 건다 — 컴포지터 설정은 resume·재열거 뒤에 풀린다. 규칙: docs/galaxy-chromebook-1.md

  # cros_ec_sensorhub's accel/gyro/light/lid-angle, for auto-rotate (iio-sensor-proxy),
  # auto-brightness and the tablet-mode switch.
  hardware.sensor.iio.enable = true;

  # Only matters for Xwayland; Wayland sessions read the pen through libinput.
  services.xserver.wacom.enable = true;

  # For Xwayland apps that ignore the compositor's scale.
  services.xserver.dpi = 192;

  environment.systemPackages = with pkgs; [
    # `display-try list|video|off|<blob>` — kexec into another display knob, no rebuild.
    # i915 reads both only at eDP init; nothing persists, so a normal boot is the way back.
    (pkgs.writeShellApplication {
      name = "display-try";
      runtimeInputs = with pkgs; [ coreutils kexec-tools systemd ];
      text = ''
        fw=/run/current-system/firmware/edid
        video_mode="1920x1080@60"
        target="''${1:-list}"

        if [ "$target" = list ]; then
          echo "targets:"
          echo "  video   -> video=eDP-1:$video_mode"
          echo "  off     -> no display override"
          shopt -s nullglob
          found=0
          for f in "$fw"/*.bin; do
            echo "  $(basename "$f" .bin) -> drm.edid_firmware=eDP-1:edid/$(basename "$f")"
            found=1
          done
          [ "$found" = 1 ] || echo "  (no EDID blobs — run nixos-rebuild switch first)"
          echo
          echo "running: $(tr ' ' '\n' < /proc/cmdline \
            | grep -E '^(drm\.edid_firmware|video)=' || echo '(no override)')"
          exit 0
        fi

        case "$target" in
          video|off) ;;
          *)
            if [ ! -e "$fw/$target.bin" ]; then
              echo "no such target: $target (try 'display-try list')" >&2
              exit 1
            fi
            ;;
        esac

        # Resolve the symlink: /run isn't populated yet when the kernel acts
        # on init=, so it has to be a real store path.
        sys="$(readlink -f /run/current-system)"

        # initrd= goes to kexec as its own argument; init= and both display
        # knobs are set below.
        cmdline="init=$sys/init"
        while read -r opt; do
          case "$opt" in
            initrd=*|init=*|drm.edid_firmware=*|video=*|"") continue ;;
            *) cmdline="$cmdline $opt" ;;
          esac
        done < <(tr ' ' '\n' < /proc/cmdline)

        case "$target" in
          off) ;;
          video) cmdline="$cmdline video=eDP-1:$video_mode" ;;
          *) cmdline="$cmdline drm.edid_firmware=eDP-1:edid/$target.bin" ;;
        esac

        echo "kernel:  $sys/kernel"
        echo "cmdline: $cmdline"
        echo
        printf 'kexec into this now? [y/N] '
        read -r reply
        case "$reply" in
          y|Y) ;;
          *) echo "aborted"; exit 0 ;;
        esac

        sudo kexec -l "$sys/kernel" --initrd="$sys/initrd" --command-line="$cmdline"
        sudo systemctl kexec
      '';
    })

    # `touchpad on|off|toggle|status` — writes the kernel inhibit flag, so any compositor works.
    (pkgs.writeShellApplication {
      name = "touchpad";
      runtimeInputs = with pkgs; [ coreutils ];
      text = ''
        find_dev() {
          for f in /sys/class/input/input*/name; do
            if [ "$(cat "$f" 2>/dev/null)" = "Synaptics TM3579-001" ]; then
              dirname "$f"
              return 0
            fi
          done
          echo "touchpad device not found" >&2
          return 1
        }

        dev="$(find_dev)"
        inhibit="$dev/inhibited"

        report() {
          if [ "$1" = "0" ]; then echo "touchpad: on"; else echo "touchpad: off"; fi
        }

        case "''${1:-status}" in
          on|enable)   echo 0 | sudo tee "$inhibit" >/dev/null; report 0 ;;
          off|disable) echo 1 | sudo tee "$inhibit" >/dev/null; report 1 ;;
          toggle)
            cur=$(cat "$inhibit")
            new=$((1 - cur))
            echo "$new" | sudo tee "$inhibit" >/dev/null
            report "$new"
            ;;
          status) report "$(cat "$inhibit")" ;;
          *) echo "usage: touchpad on|off|toggle|status" >&2; exit 1 ;;
        esac
      '';
    })
  ];
}
