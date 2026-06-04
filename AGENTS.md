# UCSD p-System Oric Port

## Overview

Port Apple II UCSD Pascal 1.3 p-System to Oric-1/Atmos (6502 @ 1MHz, 48K RAM).

Both machines use the 6502 CPU, but differ radically in hardware layout. The port strategy is to keep the p-code interpreter core (6502 code) and rewrite the Apple II-specific BIOS layer for Oric hardware.

## Project Structure

```
ucsd_pascal_1.2.dsk        # Original Apple II disk image
src/
  boot/                     # Oric bootloader (replaces Apple // boot PROM)
  bios/                     # Oric BIOS (SYSTEM.ORIC) - replaces SYSTEM.APPLE
    console.s               # Text mode console I/O (VIA $0300, ULA $BB80)
    keyboard.s             # Keyboard matrix scan (VIA PB0-3, PSG reg14)
    disk.s                 # Microdisc/Jasmin FDC interface
    printer.s              # Centronics via VIA
    video.s                # Text/hires mode switching
  interpreter/             # p-code interpreter (adapted from Apple II)
    pmachine.s             # Main interpreter loop, opcode dispatch
    arith.s                # Integer arithmetic (ADI, SBI, MPI, DVI, MODI)
    float.s                # Floating point (TRANSCEND unit)
    compare.s              # Comparison routines
    strings.s              # String operations
    iocsp.s                # CSP IOC handler (unit read/write)
    memory.s               # Segment loading, heap management
    execute.s              # Execution errors, breakpoint handling
  bootloader.s             # Stage 1: loads SYSTEM.ORIC from disk
include/
  oric_hardware.i          # Oric memory map, VIA registers, display addrs
  apple_constants.i        # Apple II constants (for reference)
  pcode_constants.i        # p-code opcodes, CSP numbers, register equates
  syscom.i                 # SYSCOM area layout
Makefile
AGENTS.md
```

## Architecture

### Layer 1: Bootloader (stage 1, ~256 bytes)
- Oric-specific, loads SYSTEM.ORIC from disk into $D000
- Initializes VIA, FDC, sets up memory map
- Replaces Apple II boot PROM + DOS loader

### Layer 2: BIOS = SYSTEM.ORIC (at $C000-$CFFF) - THE MAIN PORT TASK
Replaces Apple II's SYSTEM.APPLE / BIOS at $D000 area.
Entry points (must match Apple II Pascal BIOS calling conventions):

| Address | Name   | Function                     | Oric Implementation |
|---------|--------|------------------------------|---------------------|
| $C000   | DWRITE | Disk write sector            | WD1793 @ $0310      |
| $C003   | DREAD  | Disk read sector             | WD1793 @ $0310      |
| $C100   | CSPTBL | CSP routine jump table       | Same structure      |
| $C152   | COLD   | Cold start entry             | Init HW, load system|
| $C899   | CONCK  | Console check (key ready?)   | Keyboard scan       |
| $C9F8   | CINIT  | Console init                 | Set text mode       |
| $CA27   | PINIT  | Printer init                 | VIA printer setup   |
| $CA3F   | GRINIT | Graphics init                | Set hires mode      |
| $CA84   | DINIT  | Disk init                    | FDC + overlay RAM   |
| $CA9F   | CWRITE | Console write char           | ULA text output     |
| $CAD1   | PWRITE | Printer write char           | VIA parallel out    |
| $CB3B   | CREAD  | Console read char            | Keyboard + echo     |
| $CBCA   | CSTAT  | Console status               | Check key buffer    |
| $CC68   | DSTAT  | Disk status                  | FDC status check    |

### Layer 3: p-code Interpreter (at $D000-$EFFF) - MINIMAL CHANGES
The main p-code dispatch loop and opcode implementations.
Mostly **identical** to Apple II version except:
- Remove Apple II memory banking (LC, aux/main RAM switching)
- Adjust $C000 soft-switch references to no-ops or NOPs
- Adjust stack/heap boundaries for 48K RAM ($0000-$BFFF)
- Remove slot-dependent I/O dispatching

### Layer 4: SYSTEM.PASCAL (p-code segments) - UNCHANGED
All p-code segments (compiler, editor, filer, library) are portable.
They run identically on any p-machine with correct inner interpreter.

## Oric Memory Map

```
$0000-$00FF   Zero page (p-machine registers $50-$5E)
$0100-$01FF   6502 stack (p-machine evaluation stack)
$0200-$02FF   Interpreter workspace
$0300-$03FF   VIA 6522 I/O ($0300-$030F) + FDC
$0400-$04FF   Disk buffer / workspace
$0500-$97FF   User heap/code (NP up, KP down)
$9800-$9BFF   Standard character set (128 chars × 8 bytes)
$9C00-$9FFF   Alternate character set (112 chars × 8 bytes)
$A000-$BFDF   HIRES bitmap (200 lines × 40 bytes)
$BB80-$BF3F   TEXT screen (40×28 chars)
$C000-$CFFF   BIOS (SYSTEM.ORIC) - p-machine I/O routines
$D000-$EFFF   p-code interpreter (SYSTEM.ORIC)
$F000-$FFFF   Paged out / reserved for future
```

## Memory Layout (p-machine)

```
$0500         Start of heap (NP initial value)
  [heap grows UP toward stack]
  ...p-code segments loaded here...
  [stack grows DOWN toward heap]
$BFFF         Top of stack (KP initial value)
```

## Oric Hardware Key Notes

### VIA 6522 ($0300-$030F)
- $0300: PRB/IRB - keyboard column + printer strobe + tape
- $0301: PRA/IRA - PSG data + printer data
- $0302: DDRB - data direction B
- $0303: DDRA - data direction A
- $0304-$0307: Timer 1 (system tick ~10ms)
- $0308-$0309: Timer 2
- $030A: Shift register
- $030B: ACR
- $030C: PCR
- $030D: IFR (interrupt flags)
- $030E: IER (interrupt enable)

### Display (ULA)
- Text: $BB80-$BF3F = 40×28 chars
- Char codes $20-$7F, bit 7 = inverse
- Codes $00-$1F = inline serial attributes
- Attributes: bits 6-5 = 00 marks attribute, bits 4-3 = register, bits 2-0 = data
  - Reg 00: foreground color (ink)
  - Reg 01: style (alt charset, double height, blink)
  - Reg 10: background color (paper)
  - Reg 11: video mode (50/60Hz, TEXT/HIRES)

### Keyboard Matrix
- 8 columns selected via PB0-PB2 → PSG I/O port A (reg 14)
- Row sense: PB3 (1 = pressed)
- Scan: For each column (0-7), set PB0-2, write column mask to PSG reg14, read PB3

### Microdisc FDC ($0310-$0313)
- $0310: WD1793 data reg
- $0311: WD1793 control/status reg
- $0312: WD1793 track reg
- $0313: WD1793 sector reg
- $0314: Control (drive select, side, density, overlay)
- $0318: DRQ status (bit 7)
- Overlay RAM at $C000-$FFFF when ROM disabled

### IRQ
- VIA Timer 1 generates 10ms interrupts
- Oric NMI is not connected
- ROM handler decrements WAIT counter, polls keyboard, updates clock

## Microdisc ROM Boot Flow (Critical - Reverse Engineered)

The Microdisc ROM (8KB at $E000-$FFFF) has its own boot sequence that is **not** compatible with Apple II-style chain-loading from sector 0. Understanding this is essential for creating a bootable p-System disk.

### ROM Reset Flow ($EB7E)

```
RESET → init hardware → set memory bounds ($97FF top) → init I/O vectors
  → PRINT "insert system disc" to screen (DEFAULT, $ECBB)
  → Read track 0, sector 1 to $C000 ($ECDD)
  → Copy "SYSTEMDOS" key from $EE40-$EE49 to $C12B-$C134 ($ECC0)
  → Init check: LDA $C013 from boot sector; if ZERO → error ($E846)
  → Search directory at $C026+ for "SYSTEMDOS" filename ($ECE3)
    ├── NOT FOUND → error handler (screen stays on "insert system disc")
    └── FOUND → clear screen ($ECE6)
                → print boot message from $ED5A (copied to $9FD0 then to screen)
                → print "ORIC EXTENDED BASIC V1.x" (from $EDF1)
                → Copy 27-byte JMP vector table from $ED3F to $BFE0 ($ECFF-$ED08)
                → Check boot sector byte $C007 for BAS vector selection ($ED09)
                  ├── $C007=0 → vector = $EDAE (default)
                  └── $C007≠0 → vector = $EDF1 (alt)
                → JSR ($0C) via $E854 → execute selected vector ($EDAE or $EDF1)
                → Copy 10 bytes from $EE4A to $C12B-$C134 (sets up BOOTUPCOM search key?)
                → Search directory for "BOOTUPCOM" ($ED28)
                  ├── FOUND → JMP $BFE0 → JMP ($C14B) → execute
                  └── NOT FOUND → print "Ready", JMP $BFE0 (BASIC prompt)
```

### Key Facts
- **"insert system disc"** is the **default boot screen** — it's displayed immediately at $ECBB before any disk access. The screen is only cleared at $ECE6 after a successful "SYSTEMDOS" directory search.
- **The ROM reads track 0, sector 1** (not sector 0!) to $C000 at $ECDD via `LDA #$13 / STA $0311` (Read Sector command = $13).
- **Directory format**: 16-byte entries starting at offset $26 of the sector ($C026 in CPU space).
  - Bytes 0-8: filename (9 bytes, space-padded)
  - Bytes 9-11: extension (3 bytes)
  - Byte 12: descriptor track
  - Byte 13: descriptor sector
  - Byte 14: number of sectors in file
  - Byte 15: flags ($40 = UNPROT, $00 = PROT)
- **Expected filenames**: First "SYSTEMDOS" (the directory/filer kernel), then "BOOTUPCOM" (the executable to run).
- **The ROM does NOT chain-load from sector 0** — it expects a Sedoric/Stratsed directory structure.
- **Init check at $E846**: `LDX $C000` (always 0 for first entry), then `LDA $C013,X` → checks byte at offset $13 of boot sector. **Must be non-zero** (e.g. $FF) or the ROM returns to "insert system disc" screen.
- **Search key** at $C12C-$C134: 9 bytes copied from $EE41-$EE49 in reverse via `LDA $EE40,X / STA $C12B,X` with X=9..0. Result at $C12C-$C134 = "SYSTEMDOS".
- **$C14B vector setup**: After SYSTEMDOS file loading, $C14B = $C023 and $C14C = $C024 from the data sector (forward pointer stored at $E394). The vector table at $BFE0 ends with `JMP ($C14B)` at $BFF8-$BFFA ($6C $4B $C1). The `JMP $BFE0` at $ED3C thereby redirects to whatever address $C14B points to.

  **Critical insight**: The forward pointer bytes $C023-$C024 are reused as the JMP vector target. For a successful boot, set:
  - $C023 = low byte of page containing entry address
  - $C024 = high byte of page containing entry address
  - Then JMP ($C14B) = JMP (pointer at $C023,$C024)

  For example: $C023=$00, $C024=$C0 → JMP ($C000). The entry address must be at $C000-$C001 as a 2-byte pointer (not 6502 code!).
- **No BOOTUPCOM required**: If BOOTUPCOM is not found, the ROM still JMP $BFE0 and executes the same vector table. For our p-System, SYSTEMDOS can be the sole file that triggers boot.

### Boot Sector Content Required
For the p-System to boot, we must provide a disk where track 0, sector 1 contains a valid Sedoric directory structure. The boot sector must set:
- **$C013** = non-zero (passes init check)
- **$C026-$C02E**: first directory entry = "SYSTEMDOS" (9 bytes name + extension bytes)
- **$C033-$C034**: directory track/sector pointer (e.g., track 1, sector 1)

### Sedoric File System Format (Data Layout)

The Sedoric format uses a multi-level indirection for file storage:

#### Directory Sector (256 bytes)
```
Offset  Usage
$00-$22 Header/reserved
$23-$24 Forward pointer (track, sector) for next directory sector (0,0 = last)
$25     File count in directory
$26+    16-byte entries:
  [0-8]  Filename (9 bytes, space-padded)
  [9-11] Extension (3 bytes)
  [12]   Descriptor track
  [13]   Descriptor sector
  [14]   Number of sectors
  [15]   Flags ($40=UNPROT)
```

#### Descriptor Sector (256 bytes)
Each data block = 2 bytes (track, sector), followed by $FF terminator:
```
$00-$22: header/reserved
$23-$24: forward pointer
$25-$2C: metadata
$2D+: pairs of (data_track, data_sector), terminated by $FF
```

#### Data Sector (256 bytes) - Count-Group Format
```
$00-$22   Header/reserved
$23-$24   Forward pointer (track, sector; 0,0 = none)
$25-$2C   Metadata (including $27-$28 = copy destination address!)
$2D+      Count-groups: [count_byte, count_bytes_of_data...]
  count = $00: skip
  count = $01-$FE: copy that many bytes to destination
  count = $FF: end of sector data
```

**Critical**: The copy destination address comes from $C027-$C028 of the **data sector** (NOT the directory entry!), read at $E4FC-$E505. Default via Sedoric name encoding: SYSTEMDOS → $59, $53 → destination $5359.

**Copy loop** ($E579-$E5C1): Reads count-groups from data sector at $C000, copies to destination address. Each group is [count] followed by [count bytes]. After one group, advances to next count byte. Continues until either sector count ($C12D) reaches 0 or forward pointer ($C14B-$C14C) is 0,0.

### Current Boot Strategy (p-System)

**SYSTEMDOS = Mini Boot Loader** (~192 bytes loaded to $C000 via count-group from 1 data sector):

1. Boot sector on track 0, sector 1 has directory entry for SYSTEMDOS
2. ROM finds SYSTEMDOS, reads descriptor → reads 1 data sector
3. Data sector $C027-$C028 = $00, $C0 → dest = $C000
4. Data sector $C023-$C024 = $00, $C1 → $C14B = $C100 → JMP ($C100)
5. But we use $00,$C0 instead → JMP ($C000)
6. First 2 bytes of data ($C000-$C001) = entry address for JMP indirect
7. Boot loader at $C002+ runs, uses WD1793 FDC to load full system.rom from disk
8. Boot loader jumps to COLD ($C152) which initializes p-machine → interpreter at $D100

## Porting Strategy

### Phase 1: Bootloader + BIOS skeleton
1. Understand Microdisc ROM boot format (Sedoric/Stratsed directory on track 0, sector 1)
2. Create bootable disk with valid directory structure for the ROM
3. Write BIOS entry points (stubs that return success)
4. Verify interpreter can start, reach "Welcome" screen

### Phase 2: Console I/O
1. Implement CWRITE (character output via ULA text)
2. Implement CREAD (keyboard input via VIA + PSG matrix)
3. Implement CSTAT (check if key pressed)
4. Implement CINIT (set up text mode)
5. Test: interpreter boots, displays text, accepts keyboard

### Phase 3: Disk I/O
1. Implement DREAD/DWRITE for Microdisc (WD1793)
2. Implement DINIT (FDC + overlay RAM init)
3. Test: filer can read directories, load files

### Phase 4: Interpreter adaptation
1. Remove Apple II memory banking (LC, aux/main RAM) from interpreter
2. Adjust segment buffer addresses for Oric layout
3. Set IORSLT/SYSCOM appropriately for Oric
4. Test: full system boots, compiler/editor/filer work

### Phase 5: Polish
1. Printer support (Centronics via VIA)
2. HIRES graphics support
3. Tape I/O fallback
4. Optimize memory usage

## Build System

Use OSDK (Oric Software Development Kit) cc65 toolchain:
- `xa` or `cc65` for 6502 assembly
- `xlink` or `ld65` for linking
- `osdk-tools` for Oric disk image creation
- Oricutron for emulation/testing

## Key Apple II Differences to Remove

Search all interpreter code for these patterns:

| Apple II Feature | Oric Replacement |
|-----------------|------------------|
| $C000 KBD | VIA PB3 + PSG matrix scan |
| $C010 KBDSTRB | NOP (done by VIA read) |
| $C051 SETTXT | Write attribute to ULA |
| $C052 SETGR | Write attribute to ULA |
| $C054 TXTPAGE1 | NOP (only one page) |
| $C057 HIRES | Write attribute to ULA |
| $C081 ROMIN | NOP (or: overlay control) |
| $C083/$C08B LC banking | NOP (48K flat) |
| $C002/$C004 aux/main | NOP (flat memory) |
| Slot I/O ($C0nX) | FDC at $0310 |
| $D000 BIOS area | Move to $C000 |
| $BF00 BIOS page | Move or adapt |
| 6502 stack = eval stack | KEEP (same on Oric) |

## Reference Documents

- `http://pascal.hansotten.com/uploads/ucsd/pcode/applepascalinterpreter%20PMACH13.TXT` - Apple Pascal 1.3 p-machine source (annotated 6502 disassembly)
- `http://pascal.hansotten.com/uploads/ucsd/apple/ii/Hyde_P-Source-A%20Guide%20to%20the%20APPLE%20Pascal%20System_1983.pdf` - P-Source guide
- `http://pascal.hansotten.com/uploads/ucsd/softech/UCSD%20P-System%20&%20UCSD%20PASCAL_Internal_Architecture_Guide.pdf` - Internal Architecture Guide
- `https://wiki.defence-force.org/index.php?title=Oric_hardware` - Oric hardware wiki
- `http://www.defence-force.org/computing/oric/docs/ula.txt` - ULA documentation
- Oricutron emulator source (for hardware reference)
