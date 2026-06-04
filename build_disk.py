#!/usr/bin/env python3
"""
Build a Sedoric-format Oric disk with p-System.

The Microdisc ROM boot flow:
1. Read track 0, sector 1 to $C000
2. Check $C013 != 0
3. Search directory at $C026+ for "SYSTEMDOS" (9-byte name)
4. Read descriptor sector from entry offsets 11-12 ($C031-$C032)
5. Set dest addr from descriptor $C027-$C028, JMP vec from descriptor $C02B-$C02C
6. Read data sector(s), copy count-group data to dest
7. Return to ROM: clear screen, print boot msg, copy vector table to $BFE0
8. Print "!BOOTUPCOM" search key at $C12B, JSR $E00C search (never needed)
9. JMP $BFE0 → SEI → enable overlay ($0314=$84) → JSR $BFF8 → JMP ($C14B)
10. JMP ($C14B) uses descriptor's $C02B-$C02C as pointer address
11. Word at pointer address = entry address for JMP indirect
12. Our boot loader runs, reads full system.rom from disk
13. Jump to COLD ($C152)
"""
import struct

SEC = 256
SPT = 17
TRACKS = 40

def build_disk(system_rom_path, output_path):
    with open(system_rom_path, 'rb') as f:
        system = f.read()
    
    total_sectors = (len(system) + SEC - 1) // SEC
    print(f"system.rom: {len(system)} bytes, {total_sectors} sectors")
    
    disk = bytearray(TRACKS * SPT * SEC)
    
    # =================================================================
    # BOOT LOADER (loaded to $C000 by SYSTEMDOS, first 192 bytes)
    # =================================================================
    boot = bytearray(SEC)
    
    # --- Boot sector header ---
    boot[0x13] = 0xFF  # Init check ($C013)
    boot[0x25] = 1     # File count = 1 (SYSTEMDOS only)
    
    # Directory entry for SYSTEMDOS at $C026 (16 bytes)
    name = b'SYSTEMDOS'
    for i, c in enumerate(name): boot[0x26 + i] = c
    # Extension (2 bytes) - leave as spaces
    boot[0x2F] = 0x20; boot[0x30] = 0x20
    # Descriptor: track 1, sector 2
    boot[0x31] = 2    # descriptor sector
    boot[0x32] = 1    # descriptor track
    boot[0x33] = 1    # sectors count
    boot[0x34] = 0x40 # UNPROT flags
    
    # =================================================================
    # BOOT LOADER MACHINE CODE
    # =================================================================
    # Entry at $C040 through JMP ($C000) → $C040.
    # Bytes $C000-$C001 = entry word $40 $C0.
    #
    # Boot sector header layout:
    #   $C000-$C001: entry address for JMP ($C000)
    #   $C013:       init check flag (non-zero)
    #   $C025:       file count
    #   $C026-$C02E: "SYSTEMDOS" (9 bytes directory name)
    #   $C02F-$C030: extension (2 bytes)
    #   $C031:       descriptor sector
    #   $C032:       descriptor track
    #   $C033:       file sectors count
    #   $C034:       flags ($40 = UNPROT)
    #   $C040+:      boot loader code (safe area after header)
    #
    # The boot loader reads system.rom sectors 2-64 from disk to $C100-$FFFF
    # Then reads sector 1 to $C000 (overwriting itself)
    # Then jumps to $C152 (COLD)
    #
    # Disk layout for system.rom data:
    #   Track 1, sector  4:  system.rom bytes   0-255   (sector 1 - loaded by Phase 1)
    #   Track 1, sector  5:  system.rom bytes 256-511   (sector 2)
    #   Track 1, sectors 6-17: sectors 3-14 (12 more)
    #   Track 2, sectors 1-17: sectors 15-31
    #   Track 3, sectors 1-17: sectors 32-48
    #   Track 4, sectors 1-16: sectors 49-64
    
    # === Configure boot sector header first ===
    boot[0] = 0x40   # Entry low byte → JMP ($C000) → $C040
    boot[1] = 0xC0   # Entry high byte
    
    # Init check at $C013
    boot[0x13] = 0xFF
    
    # Directory entry for SYSTEMDOS at $C026 (16 bytes)
    # ROM layout (X=3 offset from $C02E/$C02F):
    #   [0-8]  name    ($C026-$C02E, 9 bytes)
    #   [9-10] ext     ($C02F-$C030, 2 bytes)
    #   [11]   sector  ($C031) → descriptor sector
    #   [12]   track   ($C032) → descriptor track
    #   [13]   sectors ($C033) file size in sectors
    #   [14]   flags   ($C034)  
    #   [15]   unused  ($C035)
    name = b'SYSTEMDOS'
    for i, c in enumerate(name): boot[0x26 + i] = c
    # Extension (2 bytes) - leave as spaces
    boot[0x2F] = 0x20; boot[0x30] = 0x20
    
    # Descriptor location (track 1, sector 2)
    boot[0x31] = 2   # descriptor sector
    boot[0x32] = 1   # descriptor track
    
    # Number of sectors in file
    boot[0x33] = 1
    
    # Flags
    boot[0x34] = 0x40  # UNPROT
    
    # File count
    boot[0x25] = 1
    
    # === Now assemble boot loader starting at $C040 ===
    code_offs = 0x40  # Start of code at offset $40
    
    def emit(byte):
        nonlocal code_offs
        assert code_offs < SEC, "Boot loader too large!"
        boot[code_offs] = byte
        code_offs += 1
        return code_offs
    
    # Code starts at $C040
    # Zero page usage: $12-13=dest address for ($12),Y read loop, $14=counter
    
    # =================================================================
    # Phase 1: Read system.rom sector 1 (track 1, sector 4) to $0400
    # Safe buffer $0400 avoids self-overwrite of boot loader at $C000
    #
    # NOTE: system.rom starts at track 1, sector 4 because sectors
    # 1-3 are: dir (1), desc (2), SYSTEMDOS data (3).
    # =================================================================
    
    # SEI
    emit(0x78)
    
    # Set track = 1, sector = 4, dest = $0400
    emit(0xA9); emit(0x01)
    emit(0x8D); emit(0x12); emit(0x03)  # STA $0312 (track)
    emit(0xA9); emit(0x04)
    emit(0x8D); emit(0x13); emit(0x03)  # STA $0313 (sector)
    emit(0xA9); emit(0x00)
    emit(0x85); emit(0x12)               # STA $12 (dest low)
    emit(0xA9); emit(0x04)
    emit(0x85); emit(0x13)               # STA $13 (dest high)
    
    # Read command + wait + read 256 bytes to ($12) = $0400
    emit(0xA9); emit(0x88)
    emit(0x8D); emit(0x11); emit(0x03)   # STA $0311 (read command)
    p1_wait = 0xC000 + code_offs
    emit(0xAD); emit(0x18); emit(0x03)   # LDA $0318
    emit(0x10); emit(0xFB)               # BPL p1_wait (relative -5)
    emit(0xA0); emit(0x00)               # LDY #$00
    p1_read = 0xC000 + code_offs
    emit(0xAD); emit(0x10); emit(0x03)   # LDA $0310
    emit(0x91); emit(0x12)               # STA ($12),Y
    emit(0xC8)                           # INY
    emit(0xD0); emit(0xF8)               # BNE p1_read (relative -8 = $F8)
    
    # =================================================================
    # Phase 2: Read 63 sectors (system.rom sectors 2-64) to $C100-$FFFF
    # Track/sector layout:
    #   Track 1, sector  5-17: 13 sectors  (system.rom sectors  2-14)
    #   Track 2, sector  1-17: 17 sectors  (system.rom sectors 15-31)
    #   Track 3, sector  1-17: 17 sectors  (system.rom sectors 32-48)
    #   Track 4, sector  1-16: 16 sectors  (system.rom sectors 49-64)
    # =================================================================
    
    # Initialize counter = 0
    emit(0xA9); emit(0x00)
    emit(0x85); emit(0x14)               # STA $14 (counter)
    
    # Set track = 1, sector = 5, dest = $C100
    emit(0xA9); emit(0x01)
    emit(0x8D); emit(0x12); emit(0x03)   # STA $0312 (track)
    emit(0xA9); emit(0x05)
    emit(0x8D); emit(0x13); emit(0x03)   # STA $0313 (sector)
    emit(0xA9); emit(0x00)
    emit(0x85); emit(0x12)               # STA $12 (dest low)
    emit(0xA9); emit(0xC1)
    emit(0x85); emit(0x13)               # STA $13 (dest high)
    
    # -- main_loop: read one sector to ($12) --
    main_loop_addr = 0xC000 + code_offs
    
    emit(0xA9); emit(0x88)
    emit(0x8D); emit(0x11); emit(0x03)   # STA $0311 (read command)
    p2_wait = 0xC000 + code_offs
    emit(0xAD); emit(0x18); emit(0x03)   # LDA $0318
    emit(0x10); emit(0xFB)               # BPL p2_wait
    emit(0xA0); emit(0x00)               # LDY #$00
    p2_read = 0xC000 + code_offs
    emit(0xAD); emit(0x10); emit(0x03)   # LDA $0310
    emit(0x91); emit(0x12)               # STA ($12),Y
    emit(0xC8)                           # INY
    emit(0xD0); emit(0xF8)               # BNE p2_read
    
    # Advance dest high byte
    emit(0xE6); emit(0x13)               # INC $13
    
    # Advance sector
    emit(0xEE); emit(0x13); emit(0x03)   # INC $0313
    
    # Check if sector wrapped past 17
    emit(0xAD); emit(0x13); emit(0x03)   # LDA $0313
    emit(0xC9); emit(0x12)               # CMP #18
    emit(0xD0); emit(0x08)               # BNE same_track (skip 8 bytes of wrap code)
    
    # Sector wrapped: reset to 1, inc track
    emit(0xA9); emit(0x01)
    emit(0x8D); emit(0x13); emit(0x03)   # STA $0313
    emit(0xEE); emit(0x12); emit(0x03)   # INC $0312
    
    # -- same_track: check loop counter --
    p2_same = 0xC000 + code_offs
    emit(0xE6); emit(0x14)               # INC $14
    emit(0xA5); emit(0x14)               # LDA $14
    emit(0xC9); emit(0x3F)               # CMP #63
    rel = main_loop_addr - (0xC000 + code_offs + 2)
    emit(0xD0); emit(rel & 0xFF)         # BNE main_loop
    
    # =================================================================
    # Phase 3: Copy stub to $0200, JMP to copy $0400→$C000 → $C152
    #
    # Stub at $0200 copies system.rom sector 1 from $0400 to $C000
    # and jumps to COLD start. Code runs from $0200 (safe from overwrite).
    # Stub bytes:
    #   A0 00 B9 00 04 99 00 C0 C8 D0 F7 4C 52 C1
    # =================================================================
    
    # Copy 14-byte stub from code body to $0200
    # Stub: LDY #0; LDA $0400,Y; STA $C000,Y; INY; BNE; JMP $C152
    # Bytes: A0 00 B9 00 04 99 00 C0 C8 D0 F7 4C 52 C1
    emit(0xA2); emit(0x0D)               # LDX #$0D (14 bytes - 1)
    stub_copy = 0xC000 + code_offs
    # LDA stub_data,X   (calculated after we know stub_data address)
    emit(0xBD)
    stub_data_addr = 0xC000 + code_offs  # low byte is at current code_offs
    emit(0x00)  # placeholder: low byte of stub_data
    stub_data_addr_hi = 0xC000 + code_offs  # high byte is at current code_offs
    emit(0x00)  # placeholder: high byte of stub_data
    emit(0x9D); emit(0x00); emit(0x02)   # STA $0200,X
    emit(0xCA)                           # DEX
    emit(0x10); emit(0xF7)               # BPL stub_copy
    
    emit(0x4C); emit(0x00); emit(0x02)   # JMP $0200
    
    # Now fill in the stub_data placeholder bytes
    stub_data_start = code_offs
    # Stub bytes: LDY #0; LDA $0400,Y; STA $C000,Y; INY; BNE; JMP $C152
    emit(0xA0); emit(0x00)               # LDY #$00
    emit(0xB9); emit(0x00); emit(0x04)   # LDA $0400,Y
    emit(0x99); emit(0x00); emit(0xC0)   # STA $C000,Y
    emit(0xC8)                           # INY
    emit(0xD0); emit(0xF7)               # BNE ($0202 = LDA $0400,Y)
    emit(0x4C); emit(0x52); emit(0xC1)   # JMP $C152
    
    # Now fix the stub_data address in the copy loop
    stub_data_addr_fixed = 0xC000 + stub_data_start
    boot[stub_data_addr - 0xC000] = stub_data_addr_fixed & 0xFF
    boot[stub_data_addr_hi - 0xC000] = (stub_data_addr_fixed >> 8) & 0xFF
    
    print(f"Boot loader code: {code_offs} bytes ({code_offs-0x40} code bytes, max 192)")
    
    # =================================================================
    # Write boot sector to disk (track 0, sector 1)
    # =================================================================
    disk[0:SEC] = boot
    
    # =================================================================
    # Directory sector (track 1, sector 1)
    # =================================================================
    dir_off = (1 * SPT + 0) * SEC
    dir_sec = bytearray(SEC)
    
    # SYSTEMDOS entry
    for i, c in enumerate(b'SYSTEMDOS'): dir_sec[i] = c
    dir_sec[14] = 1    # sectors
    dir_sec[15] = 0x40 # UNPROT
    # Descriptor: track 1, sector 2
    dir_sec[12] = 1
    dir_sec[13] = 2
    
    disk[dir_off:dir_off+SEC] = dir_sec
    
    # =================================================================
    # Descriptor sector (track 1, sector 2)
    # =================================================================
    desc_off = (1 * SPT + 1) * SEC
    desc_sec = bytearray(SEC)
    # Forward pointer: must be 0 to prevent second read
    desc_sec[0x23] = 0x00  # forward track (→ $C001)
    desc_sec[0x24] = 0x00  # forward sector (0 = done)
    # Metadata: destination address ($C027-$C028)
    desc_sec[0x27] = 0x00  # dest low
    desc_sec[0x28] = 0xC0  # dest high → $C000
    # Metadata: JMP vector ($C02B-$C02C → $C14B-$C14C)
    desc_sec[0x2B] = 0x00  # JMP indirect addr low
    desc_sec[0x2C] = 0xC0  # JMP indirect addr high → JMP ($C000)
    # Data pairs: track 1, sector 3
    desc_sec[0x2D] = 1     # data track
    desc_sec[0x2E] = 3     # data sector
    desc_sec[0x2F] = 0xFF  # end of pairs
    disk[desc_off:desc_off+SEC] = desc_sec
    
    # =================================================================
    # Data sector for SYSTEMDOS (track 1, sector 3)
    # =================================================================
    data_off = (1 * SPT + 2) * SEC
    data_sec = bytearray(SEC)
    
    # Forward pointer ($C023-$C024):
    #   $C024 checked at $E5B8: if 0 → BEQ → RTS (no forward)
    #   If non-zero → JSR $E83F reads sector from track=$C001, sector=$C024
    data_sec[0x23] = 0x00  # forward track → $C001 (ignored if sector=0)  
    data_sec[0x24] = 0x00  # forward sector = 0 → BEQ → RTS (no second read)
    
    # Note: $C14B-$C14C (JMP vector) and $C14D-$C14E (destination)
    # come from the DESCRIPTOR sector metadata, not from the data sector.
    # The descriptor ($C027-$C028 = dest, $C02B-$C02C = JMP vec) is set above.
    # These fields in the data sector are for the count-group copy loop:
    
    # Copy destination ($C027-$C028): where the count-group copies to
    # (overridden by descriptor metadata, but kept for consistency)
    data_sec[0x27] = 0x00
    data_sec[0x28] = 0xC0
    
    # Count-group: copy boot loader (header + code)
    count = code_offs  # Total bytes from $C000 to end of code
    data_sec[0x2D] = count
    
    # Fill boot loader data (full 256 byte sector, but count-group only copies boot portion)
    for i in range(count):
        data_sec[0x2E + i] = boot[i]
    
    # End marker
    data_sec[0x2E + count] = 0xFF
    
    print(f"Data sector count-group: {count} bytes + $FF")
    disk[data_off:data_off+SEC] = data_sec
    
    # =================================================================
    # System.rom data sectors (track 1 sectors 4-17, tracks 2-4)
    # =================================================================
    sys_sector = 1  # Which system.rom sector (1-indexed)
    total_written = 0
    
    for track in range(1, TRACKS):
        for sector_num in range(1, SPT + 1):
            # Skip tracks 0-1 sectors that are used for boot/dir/desc
            if track == 1 and sector_num <= 3:
                continue
            
            if sys_sector > total_sectors:
                break
            
            # Read system.rom data for this sector
            offset = (sys_sector - 1) * SEC
            chunk = system[offset:offset+SEC]
            
            # Write to disk
            disk_off = (track * SPT + sector_num - 1) * SEC
            for i, b in enumerate(chunk):
                disk[disk_off + i] = b
            
            total_written += len(chunk)
            sys_sector += 1
        
        if sys_sector > total_sectors:
            break
    
    print(f"Total system.rom bytes written: {total_written}")
    
    # =================================================================
    # Write disk image
    # =================================================================
    with open(output_path, 'wb') as f:
        f.write(disk)
    
    print(f"Created {output_path} ({len(disk)} bytes)")
    
    # Verify boot sector key fields
    print("\n--- Verification ---")
    print(f"$C013 = ${boot[0x13]:02X} (must be non-zero)")
    print(f"Name at $C026: {bytes(boot[0x26:0x2F]).decode('ascii', errors='replace')}")
    print(f"$C031 (desc sector): {boot[0x31]}")
    print(f"$C032 (desc track):  {boot[0x32]}")
    print(f"$C033 (sectors):     {boot[0x33]}")
    print(f"$C034 (flags):       ${boot[0x34]:02X}")
    print(f"$C025 (file cnt):  {boot[0x25]}")
    
    # Verify descriptor sector key fields
    print(f"\nDescriptor $C027 (dest lo): ${desc_sec[0x27]:02X}")
    print(f"Descriptor $C028 (dest hi): ${desc_sec[0x28]:02X}")
    print(f"  → dest = ${desc_sec[0x28]:02X}{desc_sec[0x27]:02X}")
    print(f"Descriptor $C02B (→ $C14B): ${desc_sec[0x2B]:02X}")
    print(f"Descriptor $C02C (→ $C14C): ${desc_sec[0x2C]:02X}")
    print(f"  → JMP (${desc_sec[0x2C]:02X}{desc_sec[0x2B]:02X})")
    print(f"Descriptor $C023 (fwd track): {desc_sec[0x23]}")
    print(f"Descriptor $C024 (fwd sector): {desc_sec[0x24]}")
    print(f"Descriptor $C02D (data pair): track={desc_sec[0x2D]}, sector={desc_sec[0x2E]}")
    
    # Display boot loader disassembly
    print(f"\n--- Boot Loader Disassembly ---")
    print(f"Address | Bytes      | Instruction")
    for i in range(0, code_offs, 1):
        b = boot[i]
        addr = 0xC000 + i
        comment = ""
        # Basic instruction detection
        if b == 0x78:
            comment = "SEI"
        elif b == 0x58:
            comment = "CLI"
        elif b == 0x60:
            comment = "RTS"
        elif b == 0x00:
            comment = "BRK"
        elif b == 0xA9 and i + 1 < code_offs:
            comment = f"LDA #${boot[i+1]:02X}"
        elif b == 0x85 and i + 1 < code_offs:
            comment = f"STA ${boot[i+1]:02X}"
        elif b == 0x86 and i + 1 < code_offs:
            comment = f"STX ${boot[i+1]:02X}"
        elif b == 0x84 and i + 1 < code_offs:
            comment = f"STY ${boot[i+1]:02X}"
        elif b == 0xA5 and i + 1 < code_offs:
            comment = f"LDA ${boot[i+1]:02X}"
        elif b == 0xA6 and i + 1 < code_offs:
            comment = f"LDX ${boot[i+1]:02X}"
        elif b == 0xE6 and i + 1 < code_offs:
            comment = f"INC ${boot[i+1]:02X}"
        elif b == 0xC6 and i + 1 < code_offs:
            comment = f"DEC ${boot[i+1]:02X}"
        elif b == 0x4C and i + 2 < code_offs:
            target = boot[i+2] * 256 + boot[i+1]
            comment = f"JMP ${target:04X}"
        elif b == 0x20 and i + 2 < code_offs:
            target = boot[i+2] * 256 + boot[i+1]
            comment = f"JSR ${target:04X}"
        elif b == 0x8D and i + 2 < code_offs:
            addr_target = boot[i+2] * 256 + boot[i+1]
            comment = f"STA ${addr_target:04X}"
        elif b == 0xAD and i + 2 < code_offs:
            addr_target = boot[i+2] * 256 + boot[i+1]
            comment = f"LDA ${addr_target:04X}"
        elif b == 0x91 and i + 1 < code_offs:
            comment = f"STA (${boot[i+1]:02X}),Y"
        elif b == 0x99 and i + 2 < code_offs:
            addr_target = boot[i+2] * 256 + boot[i+1]
            comment = f"STA ${addr_target:04X},Y"
        elif b == 0xA0 and i + 1 < code_offs:
            comment = f"LDY #${boot[i+1]:02X}"
        elif b == 0xA2 and i + 1 < code_offs:
            comment = f"LDX #${boot[i+1]:02X}"
        elif b == 0xC9 and i + 1 < code_offs:
            comment = f"CMP #${boot[i+1]:02X}"
        elif b == 0xC8:
            comment = "INY"
        elif b == 0xE8:
            comment = "INX"
        elif b == 0xCA:
            comment = "DEX"
        elif b == 0xD0 and i + 1 < code_offs:
            target = addr + 2 + (boot[i+1] if boot[i+1] < 128 else boot[i+1] - 256)
            comment = f"BNE ${target:04X}"
        elif b == 0xF0 and i + 1 < code_offs:
            target = addr + 2 + (boot[i+1] if boot[i+1] < 128 else boot[i+1] - 256)
            comment = f"BEQ ${target:04X}"
        elif b == 0x10 and i + 1 < code_offs:
            target = addr + 2 + (boot[i+1] if boot[i+1] < 128 else boot[i+1] - 256)
            comment = f"BPL ${target:04X}"
        elif b == 0x30 and i + 1 < code_offs:
            target = addr + 2 + (boot[i+1] if boot[i+1] < 128 else boot[i+1] - 256)
            comment = f"BMI ${target:04X}"
        
        if i + 2 < code_offs and b in [0xA9]:
            print(f"${addr:04X} | ${b:02X} ${boot[i+1]:02X}       | {comment}")
        elif i + 2 < code_offs and b in [0x4C, 0x20, 0x8D, 0xAD, 0x99]:
            print(f"${addr:04X} | ${b:02X} ${boot[i+1]:02X} ${boot[i+2]:02X}    | {comment}")
        elif i + 1 < code_offs and b in [0x85, 0x86, 0x84, 0xA5, 0xE6, 0xC6, 0x91]:
            print(f"${addr:04X} | ${b:02X} ${boot[i+1]:02X}       | {comment}")
        else:
            print(f"${addr:04X} | ${b:02X}          | {comment}")

if __name__ == "__main__":
    build_disk(
        system_rom_path='/Users/sah/ai/UCSD-Oric/out/system.rom',
        output_path='/Users/sah/ai/UCSD-Oric/out/bootable_v4.dsk'
    )
