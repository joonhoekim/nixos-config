{ pkgs, ... }:

# Machine-specific hardware quirks for the Galaxy Chromebook 1. Anything here
# is about THIS chassis; vendor-neutral tooling lives in
# modules/nixos/packages.nix, and the Intel-but-not-chassis-specific parts
# (thermald, the iHD VAAPI driver, intel_gpu_top/i7z/cpupower, the
# intel_pstate note) moved to modules/nixos/intel.nix once a second Intel
# host existed — ./default.nix imports it.

{
  hardware.firmware = with pkgs; [
    # Sound Open Firmware — the DSP-based audio codec needs it to produce sound.
    sof-firmware

    # EDID candidates for the FHD downscale described at `boot.kernelParams`
    # below. Modern kernels carry no built-in generic EDID blobs —
    # CONFIG_DRM_LOAD_EDID_FIRMWARE only enables the *loader*, which goes to
    # /lib/firmware/edid/ and, finding nothing, fails with -2. So we ship the
    # blobs ourselves.
    #
    # These are fallbacks now — `video=` in boot.kernelParams is the primary
    # approach. They are kept because `display-try` (below) can kexec into any
    # of them without a rebuild, which makes them cheap to keep around:
    #
    #   1920x1080.bin     generic, CEA-861 1080p60
    #   1920x1080rb.bin   generic, CVT reduced-blanking (lower pixel clock)
    #   panelfhd2.bin     panel's own EDID, DTD 2 rewritten to 1080p
    #   panelfhd.bin      panel's own EDID, DTD 1 rewritten to 1080p
    #
    # panelfhd.bin is a known failure, kept only so the negative result stays
    # reproducible: booted 2026-08-02, reached greetd, panel stayed dark. All
    # the blobs that make 1080p the *preferred* timing share that flaw — see
    # the comment on boot.kernelParams.
    #
    # `clean = true` drops the presets bundled with edid-generator so only the
    # modelines below get built; the .bin filenames come from the modeline
    # names, which is what the kernel parameter references.
    (edid-generator.overrideAttrs (_: {
      clean = true;
      modelines = ''
        Modeline "1920x1080" 148.50 1920 2008 2052 2200 1080 1084 1089 1125 +hsync +vsync
        Modeline "1920x1080rb" 138.50 1920 1968 2000 2080 1080 1083 1088 1111 +hsync -vsync
      '';
    }))

    # The panel-derived candidates. Both keep the real vendor block, so the
    # connector still reads as a digital DisplayPort sink at 10bpc, where the
    # generic blobs above declare themselves *analog* — a hardcoded quirk of
    # edid-generator's template.
    # `compressFirmware = false` keeps these plain .bin like the two above.
    # The kernel would happily decompress a .zst, but leaving them
    # uncompressed keeps every candidate under one predictable name for
    # `display-try`.
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

  # Nudge the dedicated `wacom` HID driver to load instead of `hid-generic`
  # for the i2c-HID Wacom stylus (WCOM006C:00 2D1F:009D). Without it the pen
  # works as a plain pointer, with no pressure or tilt.
  boot.kernelModules = [ "wacom" ];

  # Force the 4K eDP panel down to FHD. The Samsung AMOLED's EDID advertises
  # exactly one detailed timing (3840x2160@60), so DRM exposes a single mode,
  # niri has nothing else to offer, and DMS's resolution dropdown comes up
  # empty. Compositor scale can't help — it only resizes the UI, the
  # framebuffer stays 4K — and UHD 620 does not enjoy compositing 4K.
  #
  # i915 refuses to list any mode on an eDP connector that isn't the panel's
  # fixed mode, which is the last thing standing between us and a 1080p
  # framebuffer. See the patch header for why the rest of the driver is
  # already on our side. Costs a full local kernel build on every bump.
  boot.kernelPatches = [{
    name = "i915-edp-scaled-modes";
    patch = ./kernel/i915-edp-scaled-modes.patch;
  }];

  # `video=` appends a mode to the connector's list and leaves the EDID alone.
  # That distinction is the whole ballgame on eDP: i915 treats an eDP panel's
  # *preferred* timing as its native timing, drives the link with it, and uses
  # the panel fitter to scale any smaller mode onto it. Keep 3840x2160
  # preferred and 1080p is a scaled mode; make 1080p preferred and i915
  # concludes the panel really is 1080p and transmits 1080p timing to a
  # fixed-pixel 4K panel, which displays nothing.
  #
  # Learned the hard way on 2026-08-02: substituting a whole EDID via
  # drm.edid_firmware booted fine — all the way to greetd, no i915 errors —
  # with the panel dark the entire time. The blobs in hardware.firmware above
  # survive as fallbacks, but every one of them makes 1080p preferred, so
  # panelfhd2.bin (which does not) is the only one worth another boot.
  #
  # Also note the runtime knob does not help here:
  # /sys/kernel/debug/dri/*/eDP-1/edid_override works on external HDMI/DP but
  # is inert on eDP, because i915 builds the fixed-mode list once at connector
  # init and never rebuilds it on reprobe. Verified the same day: the override
  # stores (128 bytes read back) while the live connector EDID stays the
  # panel's own 256 bytes. Hence `display-try`, which kexecs instead.
  #
  # If this ever leaves a black screen: pick the previous generation from the
  # boot menu.
  boot.kernelParams = [ "video=eDP-1:1920x1080@60" ];

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

  # thermald matters more here than on any other host — this chassis is
  # fanless — but it is not chassis-*specific*, so it lives in
  # modules/nixos/intel.nix along with the rest of the Intel-common layer.

  environment.systemPackages = with pkgs; [
    # `display-try <target>` — restart into a different display setting
    # without a rebuild. i915 only reads both knobs when it initialises the
    # eDP connector, so trying anything means restarting the kernel; this does
    # it with kexec, which skips the firmware POST and takes seconds rather
    # than a full cold boot. Nothing is persisted — the next ordinary boot
    # goes back to whatever boot.kernelParams says, which is also what makes
    # this the safe way to try something that might blank the panel.
    #
    #   display-try list          show targets and what's running
    #   display-try video         video=eDP-1:1920x1080@60 (adds a mode)
    #   display-try panelfhd2     that EDID blob (replaces the EDID)
    #   display-try off           neither knob (recovery)
    #
    # Afterwards: cat /sys/class/drm/card1-eDP-1/modes
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

        # Rebuild the command line from the running one. initrd= is dropped
        # because kexec takes the initrd as its own argument, and init= plus
        # either display knob are dropped so we can set them ourselves.
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
