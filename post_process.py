# Post-process linker output to create 16KB flat ROM for Oricutron
# The ld65 linker doesn't pad segments to their correct memory offsets,
# so we need to extract each segment and place it at the right offset.

import struct
import sys

def create_rom(input_file, output_file):
    with open(input_file, 'rb') as f:
        data = f.read()

    # Memory layout (from linker config + map):
    # BIOS:    $C000-$CFFF (4096 bytes) at file offset 0
    # BIOSDATA follows BIOS in same region
    # CODE:    $D000-$DFFF (4096 bytes) after 16KB padding

    rom = bytearray(16384)  # 16KB ROM at $C000-$FFFF

    # Read map file to get segment sizes
    # Default: BIOS ~0xF42, BIOSDATA ~0x49
    # We split BIOS+BIOSDATA from CODE data in the flat file

    # The linker concatenates segments without padding, so we need
    # to identify where BIOS ends and CODE begins.
    # BIOS starts at file offset 0.
    # CODE starts at file offset where the total BIOS+BIOSDATA ends.

    # Strategy: read map file to get segment sizes.
    # ld65 packs file=%O segments contiguously (no padding between segments).
    # The first segment in the output file is BIOS, followed by BIOSDATA,
    # then CODE. So code_start file offset = BIOS_size + BIOSDATA_size.
    map_file = input_file.replace('.ORIC', '').replace('.dsk', '') + '.map'
    map_file = map_file.replace('/SYSTEM', '/system') if '/SYSTEM' in map_file else map_file
    map_file = 'out/system.map'

    code_start = None
    bios_size = 0
    biosdata_size = 0
    try:
        with open(map_file) as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 4 and len(parts[0]) > 0 and parts[0][0].isalpha():
                    # Skip header line ("Name") and non-hex entries
                    try:
                        int(parts[3], 16)
                    except ValueError:
                        continue
                    name = parts[0].strip()
                    if name == 'BIOS':
                        bios_size = int(parts[3], 16)
                    elif name == 'BIOSDATA':
                        biosdata_size = int(parts[3], 16)
        code_start = bios_size + biosdata_size
    except (FileNotFoundError, IndexError, ValueError):
        pass

    if code_start is None or code_start <= 0:
        # Fallback: search for first JMPTBL entry (little-endian address from listing)
        # Search for known pattern: 64 d3 = P_ABI at offset $0364 (may change)
        jmptbl_pattern = bytes([0x64, 0xd3, 0x67, 0xd3, 0xe1, 0xd1])
        code_start = data.find(jmptbl_pattern)
        if code_start < 0:
            print("Error: Could not find CODE segment start", file=sys.stderr)
            code_start = 0x0F8B  # Reasonable default from known sizes

    print(f"CODE found at file offset: 0x{code_start:04x}")
    print(f"BIOS area: 0x0000-0x{code_start-1:04x} ({code_start} bytes)")
    print(f"CODE area: 0x{code_start:04x}-0x{len(data)-1:04x} ({len(data)-code_start} bytes)")

    # Copy BIOS+BIOSDATA area ($C000-$CF8A) into ROM
    bios_copy_size = min(code_start, 0x1000)  # Max 4096 bytes for $C000-$CFFF
    rom[0:bios_copy_size] = data[0:bios_copy_size]

    # Copy CODE area to $D000 (offset 0x1000 in ROM)
    code_size = min(len(data) - code_start, 0x3000)  # Up to $C000-$FFFF
    code_rom_offset = 0x1000  # D000 - C000 = $1000
    rom[code_rom_offset:code_rom_offset + code_size] = data[code_start:code_start + code_size]

    # Set reset vector at $FFFC-$FFFD to point to COLD_START ($C152)
    rom[0x3FFC] = 0x52  # $C152 low byte
    rom[0x3FFD] = 0xC1  # $C152 high byte

    # Set NMI vector ($FFFA-$FFFB) to RTS
    rom[0x3FFA] = 0x60
    rom[0x3FFB] = 0xC0

    # Set IRQ vector ($FFFE-$FFFF) to RTS
    rom[0x3FFE] = 0x60
    rom[0x3FFF] = 0xC0

    with open(output_file, 'wb') as f:
        f.write(rom)

    print(f"Created 16KB ROM: {output_file}")
    print(f"  vectors: RESET=$C152, NMI=$C060, IRQ=$C060")

if __name__ == '__main__':
    create_rom('out/SYSTEM.ORIC', 'out/system.rom')
