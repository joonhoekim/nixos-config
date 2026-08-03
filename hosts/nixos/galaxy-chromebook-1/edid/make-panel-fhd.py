#!/usr/bin/env python3
"""Derive an EDID offering 1920x1080 from this panel's real one.

The Galaxy Chromebook's Samsung ATNA33TP04-0 ships an EDID whose two detailed
timing descriptors are both 3840x2160. We rewrite one of them as 1920x1080.

Which one matters enormously, which is why it is an argument:

  slot 2  DTD 1 keeps 3840x2160, so it stays the preferred timing. i915 takes
          the preferred timing of an eDP panel as its *native* timing and
          drives the link with it, then uses the panel fitter to scale any
          smaller mode onto it. 1080p becomes an extra entry in the mode list.
          This is the arrangement that can actually work.

  slot 1  DTD 1 becomes 1920x1080 and thus preferred. Verified on 2026-08-02:
          this boots cleanly all the way to greetd but leaves the panel dark,
          because i915 concludes the panel is natively 1080p and transmits
          1080p timing to a fixed-pixel 4K panel. Kept only as a documented
          negative result — do not make it the default.

Everything else is kept byte-for-byte: vendor block, digital/DisplayPort flags,
10bpc depth, chromaticity, the product-name descriptor, and the CTA-861
extension block (which carries HDR metadata but contributes no video modes, so
it cannot smuggle 2160p back into the list). Only the base block's checksum is
recomputed; the extension block is untouched and keeps its own.

Usage: make-panel-fhd.py <panel-native.hex> <out.bin> <dtd-slot: 1|2>
"""

import sys

DTD_BASE = 0x36  # first detailed timing descriptor
DTD_LEN = 18


def encode_dtd(pclk_khz, hact, hfp, hsync, hbp, vact, vfp, vsync, vbp,
               hsize_mm, vsize_mm, hpol, vpol):
    """Pack an 18-byte EDID detailed timing descriptor."""
    hblank = hfp + hsync + hbp
    vblank = vfp + vsync + vbp
    pclk = pclk_khz // 10  # stored in 10 kHz units

    d = bytearray(DTD_LEN)
    d[0] = pclk & 0xFF
    d[1] = (pclk >> 8) & 0xFF
    d[2] = hact & 0xFF
    d[3] = hblank & 0xFF
    d[4] = ((hact >> 8) << 4) | (hblank >> 8)
    d[5] = vact & 0xFF
    d[6] = vblank & 0xFF
    d[7] = ((vact >> 8) << 4) | (vblank >> 8)
    d[8] = hfp & 0xFF
    d[9] = hsync & 0xFF
    d[10] = ((vfp & 0x0F) << 4) | (vsync & 0x0F)
    d[11] = ((hfp >> 8) << 6) | ((hsync >> 8) << 4) | \
            ((vfp >> 4) << 2) | (vsync >> 4)
    d[12] = hsize_mm & 0xFF
    d[13] = vsize_mm & 0xFF
    d[14] = ((hsize_mm >> 8) << 4) | (vsize_mm >> 8)
    d[15] = 0  # horizontal border
    d[16] = 0  # vertical border
    # bits 4:3 = 11 -> digital separate sync; bit 2 = vsync polarity;
    # bit 1 = hsync polarity. Matches how the stock descriptors encode sync.
    d[17] = 0x18 | (int(vpol) << 2) | (int(hpol) << 1)
    return bytes(d)


def main():
    src, dst, slot = sys.argv[1], sys.argv[2], int(sys.argv[3])

    if slot not in (1, 2):
        sys.exit(f"dtd slot must be 1 or 2, got {slot}")
    off = DTD_BASE + (slot - 1) * DTD_LEN

    with open(src) as f:
        edid = bytearray.fromhex("".join(f.read().split()))

    if len(edid) < 128:
        sys.exit(f"EDID too short: {len(edid)} bytes")

    # Reuse the panel's own physical dimensions rather than inventing them, so
    # DPI-derived autoscaling still lands on the right number.
    orig = edid[off:off + DTD_LEN]
    hsize_mm = ((orig[14] >> 4) << 8) | orig[12]
    vsize_mm = ((orig[14] & 0x0F) << 8) | orig[13]

    # Standard CEA-861 1080p60 timing.
    edid[off:off + DTD_LEN] = encode_dtd(
        pclk_khz=148500,
        hact=1920, hfp=88, hsync=44, hbp=148,
        vact=1080, vfp=4, vsync=5, vbp=36,
        hsize_mm=hsize_mm, vsize_mm=vsize_mm,
        hpol=True, vpol=True,
    )

    edid[127] = (-sum(edid[0:127])) & 0xFF

    assert sum(edid[0:128]) % 256 == 0, "base block checksum did not settle"
    if len(edid) >= 256:
        assert sum(edid[128:256]) % 256 == 0, "extension block checksum broke"

    with open(dst, "wb") as f:
        f.write(edid)

    print(f"wrote {dst}: {len(edid)} bytes, "
          f"DTD{slot} = 1920x1080, physical size {hsize_mm}x{vsize_mm} mm")


if __name__ == "__main__":
    main()
