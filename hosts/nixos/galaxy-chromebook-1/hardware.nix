{ config, pkgs, ... }:

# Machine-specific hardware quirks for the Galaxy Chromebook 1. Anything here
# is about THIS chassis; vendor-neutral tooling lives in
# modules/nixos/packages.nix.

{
  # Sound Open Firmware — the DSP-based audio codec needs it to produce sound.
  hardware.firmware = with pkgs; [ sof-firmware ];

  # Nudge the dedicated `wacom` HID driver to load instead of `hid-generic`
  # for the i2c-HID Wacom stylus (WCOM006C:00 2D1F:009D). Without it the pen
  # works as a plain pointer, with no pressure or tilt.
  boot.kernelModules = [ "wacom" ];

  # Failing Synaptics touchpad: default-off, manual control via the `touchpad`
  # CLI below. Mechanical phantom-touch returned after the 2026-05-24
  # bottom-panel rebend; keyboard-only is the daily posture now.
  # Kernel-level inhibit (/sys/.../inhibited) so events stop at the source,
  # independent of libinput/compositor. udev sets inhibited=1 the moment the
  # input node appears (works on boot AND on resume/re-enumeration).
  services.udev.extraRules = ''
    SUBSYSTEM=="input", KERNEL=="input*", ATTR{name}=="Synaptics TM3579-001", ATTR{inhibited}="1"
  '';

  # IIO sensors (accelerometer, gyro, ambient light, lid-angle from
  # cros_ec_sensorhub) — GNOME needs these for auto-rotate, auto-brightness
  # and the tablet-mode switch.
  hardware.sensor.iio.enable = true;

  # Stylus — X11 xf86-input-wacom driver. On Wayland, GNOME/Mutter reads the
  # pen through libinput+evdev instead, so this only matters for Xwayland.
  services.xserver.wacom.enable = true;

  # X11 HiDPI fallback for Xwayland apps that ignore the compositor's scale.
  # The Wayland session uses GNOME's own per-monitor scaling.
  services.xserver.dpi = 192;

  # Intel proactive thermal management — essential for the fanless chassis.
  services.thermald.enable = true;

  # NOTE: powerManagement.cpuFreqGovernor is intentionally NOT set. On Intel
  # CPUs the intel_pstate driver ignores generic cpufreq governors;
  # services.power-profiles-daemon (common.nix) drives the Energy Performance
  # Preference instead. `scaling_governor` always reads "powersave" — that's
  # intel_pstate naming, not the actual behavior. Switch profiles from GNOME
  # quick settings or:
  #   powerprofilesctl set {power-saver|balanced|performance}

  environment.systemPackages = with pkgs; [
    # Intel-specific inspection (the vendor-neutral set is in
    # modules/nixos/packages.nix).
    intel-gpu-tools     # intel_gpu_top, gpu-frequency, ...
    i7z                 # Intel CPU C-state / turbo detail
    nvtopPackages.intel # GPU monitor for the Intel iGPU
    # cpupower + turbostat. Taken from the running kernel's package set so it
    # matches boot.kernelPackages (linuxPackages_latest), not the default one.
    config.boot.kernelPackages.cpupower

    # `touchpad on|off|toggle|status` — compositor-agnostic, drives the
    # kernel inhibit flag set by the udev rule above.
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
