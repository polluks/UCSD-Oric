#!/usr/bin/env python3
"""
Create a bootable Oric Microdisc disk image (.dsk).

Packs the boot sector (track 0, sector 0) followed by SYSTEM.ORIC
data into a 40-track, 1-side, 17-sectors/track, 256-bytes/sector
disk image.

The disk data is stored in memory-mapped order (like system.rom):
  $C000-$CF8A: BIOS + BIOSDATA
  $CF8B-$CFFF: zero-padded gap
  $D000-$D70E: p-code interpreter

Usage: python3 makedisk.py
"""

import struct
import os

# Disk geometry
TRACKS = 40
SECTORS_PER_TRACK = 17
SECTOR_SIZE = 256
DISK_SIZE = TRACKS * SECTORS_PER_TRACK * SECTOR_SIZE

# Memory layout constants
LOAD_ADDR = 0xC000
COLD_START = 0xC152

# FDC and VIA addresses
VIA_DDRB = 0x0302
VIA_DDRA = 0x0303
FDC_CTRL = 0x0314
FDC_STAT = 0x0311
FDC_TRK = 0x0312
FDC_SEC = 0x0313
FDC_DATA = 0x0310


def make_boot_sector(num_sectors):
    """Create a 256-byte boot sector that loads SYSTEM.ORIC to $C000."""
    boot = bytearray(256)

    # Offset tracking
    o = 0

    def emit(b):
        nonlocal o
        assert o < 256, f"Boot sector overflow at offset {o}"
        if isinstance(b, int):
            boot[o] = b & 0xFF; o += 1
        else:
            for v in b: boot[o] = v & 0xFF; o += 1

    def addr_le(a):
        return [a & 0xFF, (a >> 8) & 0xFF]

    # sei
    emit(0x78)

    # lda #$FF; sta VIA_DDRB
    emit([0xA9, 0xFF, 0x8D, addr_le(VIA_DDRB)[0], addr_le(VIA_DDRB)[1]])

    # lda #$0F; sta VIA_DDRA
    emit([0xA9, 0x0F, 0x8D, addr_le(VIA_DDRA)[0], addr_le(VIA_DDRA)[1]])

    # lda #$04 (MFM, ROM disable, clk divisor=1); sta FDC_CTRL
    emit([0xA9, 0x04, 0x8D, addr_le(FDC_CTRL)[0], addr_le(FDC_CTRL)[1]])

    # lda #$03 (RESTORE); sta FDC_STAT
    emit([0xA9, 0x03, 0x8D, addr_le(FDC_STAT)[0], addr_le(FDC_STAT)[1]])

    # @wr: lda FDC_STAT; bmi @wr (wait for restore complete, bit7=busy)
    wait_restore = o
    emit([0xAD, addr_le(FDC_STAT)[0], addr_le(FDC_STAT)[1]])
    emit([0x30, (wait_restore - o - 2) & 0xFF])  # bmi back

    # lda #0; sta FDC_TRK (track=0)
    emit([0xA9, 0x00, 0x8D, addr_le(FDC_TRK)[0], addr_le(FDC_TRK)[1]])

    # lda #1; sta FDC_SEC (sector=1, sector 0 is boot)
    emit([0xA9, 0x01, 0x8D, addr_le(FDC_SEC)[0], addr_le(FDC_SEC)[1]])

    # lda #0; sta $80 (dest low byte = 0)
    emit([0xA9, 0x00, 0x85, 0x80])

    # lda #$C0; sta $81 (dest high byte = $C0)
    emit([0xA9, 0xC0, 0x85, 0x81])

    # @read_loop: lda #$80 (READSEC); sta FDC_STAT
    read_loop = o
    emit([0xA9, 0x80, 0x8D, addr_le(FDC_STAT)[0], addr_le(FDC_STAT)[1]])

    # @wait_drq: lda FDC_STAT; lsr a; bcc @wait_drq (wait for DRQ, bit0)
    wait_drq = o
    emit([0xAD, addr_le(FDC_STAT)[0], addr_le(FDC_STAT)[1]])
    emit(0x4A)  # lsr a
    emit([0x90, (wait_drq - o - 2) & 0xFF])  # bcc back

    # ldy #0
    emit([0xA0, 0x00])

    # @byte_loop: lda FDC_DATA; sta ($80),y; iny; bne @byte_loop
    byte_loop = o
    emit([0xAD, addr_le(FDC_DATA)[0], addr_le(FDC_DATA)[1]])
    emit([0x91, 0x80])  # sta ($80),y
    emit(0xC8)  # iny
    emit([0xD0, (byte_loop - o - 2) & 0xFF])  # bne back

    # inc $81 (advance dest by 256)
    emit([0xE6, 0x81])

    # inc FDC_SEC
    emit([0xEE, addr_le(FDC_SEC)[0], addr_le(FDC_SEC)[1]])

    # lda FDC_SEC; cmp #18; bne @check_done
    emit([0xAD, addr_le(FDC_SEC)[0], addr_le(FDC_SEC)[1]])
    emit([0xC9, 18])
    next_sec = o
    emit([0xD0, 0])  # placeholder for branch offset
    branch_off_pos_1 = o - 1

    # (sector wrapped: reset to 1, inc track)
    emit([0xA9, 0x01, 0x8D, addr_le(FDC_SEC)[0], addr_le(FDC_SEC)[1]])
    emit([0xEE, addr_le(FDC_TRK)[0], addr_le(FDC_TRK)[1]])

    # @check_done: lda $81; cmp #$D7; bcc @read_loop
    check_done = o
    # Fix the branch offset for bne @check_done
    boot[branch_off_pos_1] = check_done - (branch_off_pos_1 + 1)

    emit([0xA5, 0x81])  # lda $81
    emit([0xC9, 0xD9])  # cmp #$D9 (end addr high byte = $C0 + 25 sectors)
    emit([0x90, (read_loop - o - 2) & 0xFF])  # bcc back to read_loop

    # jmp COLD_START ($C152)
    emit([0x4C, addr_le(COLD_START)[0], addr_le(COLD_START)[1]])

    # Pad remaining bytes with NOPs ($EA)
    while o < 256:
        emit(0xEA)

    return bytes(boot)


def make_disk():
    """Create the disk image from system.rom."""
    rom_path = os.path.join('out', 'system.rom')
    dsk_path = os.path.join('out', 'system.dsk')

    with open(rom_path, 'rb') as f:
        rom_data = f.read()

    # The ROM is 16KB (16384 bytes)
    # We need it on disk starting from sector 1 (sector 0 is boot sector)
    # The data is in memory-mapped order already

    disk_data = bytearray(DISK_SIZE)

    # Write boot sector at track 0, sector 0 (offset 0 in disk image)
    num_data_sectors = (len(rom_data) + SECTOR_SIZE - 1) // SECTOR_SIZE
    boot_sector = make_boot_sector(num_data_sectors)
    disk_data[0:256] = boot_sector

    # Write ROM data starting at sector 1
    disk_data[SECTOR_SIZE:SECTOR_SIZE + len(rom_data)] = rom_data

    with open(dsk_path, 'wb') as f:
        f.write(disk_data)

    print(f"Created Oric disk image: {dsk_path}")
    print(f"  Geometry: {TRACKS} tracks, {SECTORS_PER_TRACK} sectors/track, {SECTOR_SIZE} bytes/sector")
    print(f"  Boot sector: track 0, sector 0")
    print(f"  System data: {len(rom_data)} bytes ({num_data_sectors} sectors)")
    print(f"  Total size: {DISK_SIZE} bytes ({DISK_SIZE // 1024} KB)")


if __name__ == '__main__':
    make_disk()
