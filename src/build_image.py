#!/usr/bin/env python3
"""
Turn the ld65 output into the p-System system image used by the boot loader.

With fill=yes in oric.cfg the linker emits a contiguous memory image:
    file offset 0x0000  BIOS memory area   ($C000-$CFFF, 0x1000 bytes)
    file offset 0x1000  INTERP memory area ($D000-$EFFF, 0x2000 bytes)

The boot loader copies the first 6400 bytes (25 sectors) linearly to $C000,
covering $C000-$D8FF.

Usage: python3 build_image.py
"""

import os
import sys

INPUT = os.path.join("out", "SYSTEM.bin")
MAP = os.path.join("out", "system.map")
OUTPUT = os.path.join("out", "SYSTEM.ORIC")

IMAGE_SIZE = 6400          # 25 sectors of 256 bytes


def segment_info(map_path):
    """Return segment info from the ld65 map."""
    info = {}
    try:
        with open(map_path) as f:
            for line in f:
                parts = line.split()
                if len(parts) < 5:
                    continue
                name = parts[0]
                if name in ("BIOS", "BIOSDATA", "CODE"):
                    try:
                        info[name] = {
                            "start": int(parts[1], 16),
                            "end": int(parts[2], 16),
                            "size": int(parts[3], 16),
                        }
                    except ValueError:
                        pass
    except OSError:
        pass
    return info


def build():
    with open(INPUT, "rb") as f:
        linked = f.read()

    if len(linked) < IMAGE_SIZE:
        sys.exit(
            f"linker output too small: {len(linked)} bytes (need >= {IMAGE_SIZE})"
        )

    image = bytearray(linked[:IMAGE_SIZE])

    with open(OUTPUT, "wb") as f:
        f.write(image)

    info = segment_info(MAP)
    bios_end = 0xC000
    for name in ("BIOS", "BIOSDATA"):
        if name in info:
            bios_end = max(bios_end, info[name]["end"] + 1)
    bios_used = bios_end - 0xC000

    print(f"Created {OUTPUT} ({len(image)} bytes)")
    if "BIOS" in info or "BIOSDATA" in info:
        print(
            f"  BIOS/BIOSDATA: $C000-$C{bios_used - 1:03X} ({bios_used} bytes used)"
        )
    if "CODE" in info:
        c = info["CODE"]
        print(
            f"  CODE         : ${c['start']:04X}-${c['end']:04X} ({c['size']} bytes)"
        )


if __name__ == "__main__":
    build()
