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

## Porting Strategy

### Phase 1: Bootloader + BIOS skeleton
1. Write Oric boot sector (loads SYSTEM.ORIC from disk)
2. Write BIOS entry points (stubs that return success)
3. Verify interpreter can start, reach "Welcome" screen

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
