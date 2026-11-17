#!/usr/bin/env python3
"""
Turn the ld65 output into the p-System system image used by the boot loader.

The linker concatenates the BIOS, BIOSDATA and CODE segments with no padding,
so CODE ends up right after BIOSDATA in the file:

    file offset 0x0000  BIOS      ($C000-$CF38)
    file offset 0x0F39  BIOSDATA  ($CF39-$CF81)
    file offset 0x0F82  CODE      ($D000-$D8BF)

The loader copies the whole image linearly to $C000, so the gap between
BIOSDATA and CODE must be restored here:

    image offset 0x0000  BIOS + BIOSDATA     -> $C000
    image offset 0x1000  CODE                -> $D000
    image offset 0x1900  end (6400 bytes = 25 sectors)

Usage: python3 build_image.py
"""

import os
import sys

INPUT = os.path.join("out", "SYSTEM.bin")
MAP = os.path.join("out", "system.map")
OUTPUT = os.path.join("out", "SYSTEM.ORIC")

CODE_BASE = 0xD000
IMAGE_SIZE = 6400          # 25 sectors of 256 bytes


def segment_sizes(map_path):
    """Return (bios_size, biosdata_size) from the ld65 map file."""
    sizes = {}
    try:
        with open(map_path) as f:
            for line in f:
                parts = line.split()
                if len(parts) < 5 or parts[0] != "BIOS" and parts[0] != "BIOSDATA":
                    continue
                try:
                    sizes[parts[0]] = int(parts[3], 16)
                except ValueError:
                    pass
    except OSError:
        pass

    if "BIOS" not in sizes:
        sys.exit(f"cannot read segment sizes from {map_path}")
    return sizes["BIOS"], sizes.get("BIOSDATA", 0)


def build():
    with open(INPUT, "rb") as f:
        linked = f.read()

    bios_size, biosdata_size = segment_sizes(MAP)
    code_offset = bios_size + biosdata_size

    if len(linked) < code_offset:
        sys.exit("linker output is shorter than the BIOS/BIOSDATA segments")

    image = bytearray(IMAGE_SIZE)
    image[0:code_offset] = linked[0:code_offset]

    code = linked[code_offset:]
    code_dest = CODE_BASE - 0xC000
    if code_dest + len(code) > IMAGE_SIZE:
        sys.exit(f"CODE segment ({len(code)} bytes) does not fit in the image")
    image[code_dest:code_dest + len(code)] = code

    with open(OUTPUT, "wb") as f:
        f.write(image)

    print(f"Created {OUTPUT} ({len(image)} bytes)")
    print(f"  BIOS+BIOSDATA: $C000-$C{bios_size + biosdata_size - 1:03X} "
          f"({bios_size + biosdata_size} bytes)")
    print(f"  CODE         : $D000-$D{len(code) - 1:03X} ({len(code)} bytes)")


if __name__ == "__main__":
    build()
