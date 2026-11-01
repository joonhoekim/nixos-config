#!/usr/bin/env python3
"""Derive an EDID offering 1920x1080 from this panel's real one (Samsung ATNA33TP04-0).

Both DTDs are 3840x2160 and one is rewritten. Slot 2 keeps 4K preferred, the arrangement
that works; slot 1 makes 1080p preferred and leaves the panel dark. The rest stays
byte-for-byte, only the base checksum is recomputed. Details: docs/galaxy-chromebook-1.md

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
