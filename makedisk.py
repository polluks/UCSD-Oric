#!/usr/bin/env python3
"""
Build a bootable Oric Microdisc (MFM_DISK) image for the p-System port.

The image is a real Sedoric-style boot disk, as expected by the Microdisc ROM:

  track 0, sector 1  Sedoric boot sector (only inspected by the ROM)
  track 0, sector 2  SYSTEMDOS descriptor: loads the boot loader to $0200
  track 0, sector 3  directory: a single "SYSTEMDOS" entry
  track 1, sector 1+ the p-System system image, read by the boot loader

Nothing here is a "ROM": the system image is loaded into the Oric's overlay
RAM by the loader at $0200, which then jumps to COLD_START ($C152).

Usage: python3 makedisk.py
"""

import os
import sys

# ---------------------------------------------------------------------------
# Disk geometry (Oric 3" / Microdisc, MFM, 17 sectors of 256 bytes)
# ---------------------------------------------------------------------------
TRACKS = 40
SECTORS = 17
SECTOR_SIZE = 256
SIDE = 0

SYS_IMAGE = os.path.join("out", "SYSTEM.ORIC")   # 6400-byte system image
LOADER = os.path.join("out", "boot.bin")         # loader assembled at $0200
DSK_PATH = os.path.join("out", "SYSTEM.dsk")

SYS_SECTORS = 25                 # 6400 bytes -> $C000-$D8FF
SYS_FIRST_TRACK = 1
SYS_FIRST_SECTOR = 1

LOADER_ADDR = 0x0200
LOADER_VECTOR = 0x0200
ZERO_TARGET = 0x9FD0             # ROM prints the boot message from here


# ---------------------------------------------------------------------------
# CRC-16 as used by the WD1793 (poly $1021, init $FFFF, MSB first)
# ---------------------------------------------------------------------------
def crc16(data, crc=0xFFFF):
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc


def sector_fields(sector, data):
    """Return the raw MFM bytes (sync marks, ID and data fields) for a sector."""
    out = bytearray()

    out += b"\x4e" * 16
    id_field = bytes([0xA1, 0xA1, 0xA1, 0xFE, 0, SIDE, sector, 1])
    crc = crc16(id_field)
    out += id_field + bytes([crc >> 8, crc & 0xFF])

    out += b"\x4e" * 16
    data_field = bytes([0xA1, 0xA1, 0xA1, 0xFB]) + data
    crc = crc16(data_field)
    out += data_field + bytes([crc >> 8, crc & 0xFF])
    return out


def encode_track(track, sectors):
    """Encode one 6400-byte MFM track. `sectors` maps 1..17 to 256-byte data."""
    out = bytearray(b"\x4e" * 40)
    for number in range(1, SECTORS + 1):
        out += sector_fields(number, sectors[number])
    if len(out) > 6400:
        raise ValueError(f"track {track} does not fit in 6400 bytes")
    out += b"\x4e" * (6400 - len(out))
    return bytes(out)


# ---------------------------------------------------------------------------
# Disk structures
# ---------------------------------------------------------------------------
def make_boot_sector():
    """Sedoric boot sector.

    The Microdisc ROM never executes it; it only checks a few bytes:
      offset $00       : must be non-zero (init check)
      offset $12/$13   : directory sector / track
    Oricutron also looks at the first 47 bytes to identify a Sedoric disk, so
    they reproduce the standard boot header (volume name "SEDORIC").
    """
    boot = bytearray(b" " * SECTOR_SIZE)

    boot[0] = 0x01                  # init check: must be non-zero
    boot[1:8] = b"\x00" * 7
    boot[8:16] = b" " * 8           # volume name padding
    boot[16] = 0x00
    boot[17] = 0x00
    boot[18] = 3                    # first directory sector
    boot[19] = 0                    # first directory track
    boot[20] = 0x00
    boot[21] = 0x00
    boot[22] = 0x01
    boot[23] = 0x00
    boot[24:31] = b"SEDORIC"
    boot[31:47] = b" " * 16
    return bytes(boot)


def make_directory(desc_sector, desc_track):
    """Directory sector: 16-byte entries start at offset 3, zero terminates."""
    directory = bytearray(SECTOR_SIZE)
    directory[0] = 0                        # forward track  (none)
    directory[1] = 0                        # forward sector (none)
    directory[2] = 1                        # number of files

    entry = 3
    name = b"SYSTEMDOS".ljust(9, b" ")
    directory[entry:entry + 9] = name
    directory[entry + 9] = 0x01             # extension / type
    directory[entry + 10] = 0x00
    directory[entry + 11] = desc_sector     # descriptor sector
    directory[entry + 12] = desc_track      # descriptor track
    directory[entry + 13] = 0x02
    directory[entry + 14] = 0x00
    directory[entry + 15] = 0x00
    return bytes(directory)


def make_descriptor(loader):
    """SYSTEMDOS descriptor: copy the loader to $0200 and jump there.

    Block layout (all offsets relative to the sector):
        +0/+1   forward track / sector (0,0 = last sector)
        +4/+5   destination address of the first block
        +8/+9   entry vector, copied to $C14B by the ROM
        +10     byte count of the first block
        +11...  data

    A subsequent block is introduced by an 0xFF marker; its own destination
    address sits at marker+2/+3 and its byte count at marker+8.
    """
    if len(loader) > 230:
        raise ValueError("boot loader too large for one descriptor sector")

    # (remaining bytes must stay zero: the ROM copy loop skips zero bytes)
    desc = bytearray(SECTOR_SIZE)

    desc[0] = 0                     # no following descriptor sector
    desc[1] = 0
    desc[4] = LOADER_ADDR & 0xFF
    desc[5] = LOADER_ADDR >> 8
    desc[8] = LOADER_VECTOR & 0xFF
    desc[9] = LOADER_VECTOR >> 8

    desc[10] = len(loader)
    desc[11:11 + len(loader)] = loader

    # Second block: write a zero byte to $9FD0 so that the Microdisc ROM's
    # "copy boot message to the screen" loop stops immediately.
    marker = 11 + len(loader)
    if marker + 10 > SECTOR_SIZE:
        raise ValueError("boot loader too large")
    desc[marker] = 0xFF
    desc[marker + 2] = ZERO_TARGET & 0xFF
    desc[marker + 3] = ZERO_TARGET >> 8
    desc[marker + 8] = 1
    desc[marker + 9] = 0x00

    # (remaining bytes are already zero: skipped by the ROM copy loop)
    return bytes(desc)


# ---------------------------------------------------------------------------
def build():
    with open(SYS_IMAGE, "rb") as f:
        system = f.read()
    with open(LOADER, "rb") as f:
        loader = f.read()

    if len(loader) < 2:
        sys.exit("boot loader is empty")
    if len(system) != SYS_SECTORS * SECTOR_SIZE:
        sys.exit(f"{SYS_IMAGE} must be {SYS_SECTORS * SECTOR_SIZE} bytes, "
                 f"got {len(system)}")

    # Sector map: (track, sector) -> 256 bytes
    sectors = {}

    # Track 0: boot sector, descriptor, directory
    sectors[(0, 1)] = make_boot_sector()
    sectors[(0, 2)] = make_descriptor(loader)
    sectors[(0, 3)] = make_directory(desc_sector=2, desc_track=0)

    # System image, starting at track 1 / sector 1
    track, number = SYS_FIRST_TRACK, SYS_FIRST_SECTOR
    for offset in range(0, len(system), SECTOR_SIZE):
        sectors[(track, number)] = system[offset:offset + SECTOR_SIZE]
        number += 1
        if number > SECTORS:
            number = 1
            track += 1

    # Encode into an MFM_DISK image
    image = bytearray()
    image += b"MFM_DISK"
    image += (1).to_bytes(4, "little")            # sides
    image += TRACKS.to_bytes(4, "little")         # tracks
    image += (1).to_bytes(4, "little")            # geometry (fixed)
    image += b"\x00" * (256 - len(image))         # header padding

    empty = bytes(SECTOR_SIZE)
    for t in range(TRACKS):
        content = {n: sectors.get((t, n), empty) for n in range(1, SECTORS + 1)}
        image += encode_track(t, content)

    with open(DSK_PATH, "wb") as f:
        f.write(image)

    print(f"Created {DSK_PATH} ({len(image)} bytes, {TRACKS} tracks)")
    print(f"  SYSTEMDOS loader: {len(loader)} bytes -> ${LOADER_ADDR:04X}")
    print(f"  System image    : {len(system)} bytes "
          f"({SYS_SECTORS} sectors from track {SYS_FIRST_TRACK})")


if __name__ == "__main__":
    build()
