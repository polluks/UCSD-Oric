# UCSD p-System Oric Port

## Overview

Port of Apple II UCSD Pascal 1.3 (p-System) to the Oric-1/Atmos (6502 @ 1MHz, 48K RAM).

Both machines use the 6502 CPU but differ significantly in hardware. The strategy is to keep the p-code interpreter core (6502) where possible and rewrite the Apple II-specific BIOS/I/O layer for Oric hardware (VIA 6522, ULA text/hires, WD1793 Microdisc FDC).

**Status: work in progress (boot/bring-up).** The build produces a bootable Microdisc **MFM_DISK** image, but the system is not yet booting to a usable UCSD p-System environment.

### Project constraints / conventions

- **No `system.rom`** in the boot path. The payload loaded by our boot flow is `out/SYSTEM.ORIC` (generated from this repo).
- Emit and use **`MFM_DISK`** images for Microdisc testing (Oricutron rejects other formats in this setup).
- Prefer `/usr/local/bin/oricutron` for emulator launches in this environment when running manually.

## Current status

Implemented / in progress:
- Sedoric-compatible Microdisc boot structures and MFM disk image generation (`makedisk.py`)
- SYSTEMDOS boot loader (`src/boot/boot.asm`, linked at `$0200`) that reads 25 sectors (6400 bytes) from track 1 into `$C000` and jumps to `COLD` (`$C152`)
- Main BIOS/interpreter image build pipeline (`src/bios.asm`, `oric.cfg`, `build_image.py` -> `out/SYSTEM.ORIC`)
- Partial WD1793 FDC, console, and BIOS bring-up in `src/bios.asm`

Known issues / TODO:
- Boot on Oricutron is still being debugged (freezes/emulator debug stops observed during boot; suspected JAM/illegal-opcode path under investigation)
- Pending console/BIOS fixes noted during bring-up: `calc_video_addr` row stride/addressing, CR/row advance behavior, `con_init` screen/attribute clear range, and banner/attribute handling
- p-code segment loading/runtime integration and end-to-end p-System operation not yet verified

## Project structure (current)

```text
AGENTS.md
README.md
Makefile
oric.cfg                     # ld65 config for main image (BIOS + CODE)
build_image.py               # convert linked output -> out/SYSTEM.ORIC (6400 bytes)
makedisk.py                  # build bootable out/SYSTEM.dsk (MFM_DISK, Sedoric layout)
include/
  oric_hardware.i            # Oric memory map, VIA/FDC/ULA constants
  pcode_constants.i          # p-code/CSP/unit constants
src/
  bios.asm                   # BIOS + interpreter/system code (single assembly unit)
  boot/
    boot.asm                 # SYSTEMDOS boot loader (runs at $0200)
    boot.cfg                 # ld65 config for boot loader
out/                         # build artifacts (generated)
  boot.bin
  SYSTEM.bin
  SYSTEM.ORIC
  SYSTEM.dsk
  system.map
```

Notes:
- `AGENTS.md` previously described a larger split file layout (`src/bios/*.s`, `src/interpreter/*.s`, etc.); the current implementation is consolidated primarily in `src/bios.asm` and `src/boot/boot.asm`.
- `out/` and local logs may be untracked in git.

## Build system

Toolchain: **cc65** (`ca65`, `ld65`) + **Python 3**.

```sh
make          # build out/SYSTEM.dsk
make image    # build out/SYSTEM.ORIC only
make emul     # oricutron -m atmos -k microdisc -d out/SYSTEM.dsk
make clean    # remove out/
```

Build flow:
1. Assemble `src/bios.asm` -> `out/bios.o`
2. Link with `oric.cfg` -> `out/SYSTEM.bin` (+ `out/system.map`)
3. `build_image.py` lays out BIOS/BIOSDATA and CODE into a 6400-byte image -> `out/SYSTEM.ORIC` ($C000 base)
4. Assemble/link boot loader (`src/boot/boot.asm`, `src/boot/boot.cfg`) -> `out/boot.bin`
5. `makedisk.py` creates `out/SYSTEM.dsk` (MFM_DISK, 1 side, 40 tracks, 17 sectors/track)

## Disk / boot (current implementation)

### Microdisc ROM expectations (Sedoric-style)

The Microdisc ROM does **not** chain-load raw sectors like an Apple II boot PROM. It expects a Sedoric-style disk structure and looks for `SYSTEMDOS` on track 0.

High-level ROM flow:
- Read track 0, sector 1 to `$C000`
- Perform init checks and search directory for `SYSTEMDOS`
- Load SYSTEMDOS descriptor/data as defined by ROM/Sedoric conventions
- Transfer control via ROM vectors / loaded payload

(See **Microdisc ROM Boot Flow** and **Sedoric File System Format** below for reverse-engineered details; these notes are critical reference material.)

### Current p-System boot strategy

- `makedisk.py` writes:
  - Track 0, sector 1: boot sector (Sedoric header fields required by ROM)
  - Track 0, sector 2: SYSTEMDOS descriptor
  - Track 0, sector 3: directory with `SYSTEMDOS` entry
  - Track 1, sector 1+: `out/SYSTEM.ORIC` (25 sectors, 6400 bytes)
- SYSTEMDOS descriptor loads the boot loader to `$0200` and sets entry to `$0200`.
- `src/boot/boot.asm` (running at `$0200`):
  - Enables overlay RAM / Microdisc FDC access (`$0314`, shadow `$0480`)
  - Restores/seeks and reads 25 sectors from disk into `$C000..` using WD1793 registers and DRQ polling
  - Uses absolute-indexed stores (`STA $C000,Y`) with a self-patched high byte for the destination page
  - Jumps to `COLD_START` (`$C152`) after loading (including fail path, currently)

No `system.rom` file is used.

## Architecture (target / in-progress)

### Layer 1: Bootloader (Microdisc, stage payload)
- Sedoric-compatible `SYSTEMDOS` payload loaded by Microdisc ROM
- Current implementation: loader at `$0200` loads 6400-byte system image to `$C000` and jumps to `$C152`

### Layer 2: BIOS = SYSTEM.ORIC ($C000-$CFFF) - main port task
Replaces Apple II BIOS behavior for Oric hardware. Entry points/calling conventions must remain compatible with the p-machine/interpreter expectations.

Representative entry points (subject to refinement as bring-up progresses):

| Address | Name   | Function                     | Oric Implementation |
|---------|--------|------------------------------|---------------------|
| $C000   | DWRITE | Disk write sector            | WD1793 @ $0310      |
| $C003   | DREAD  | Disk read sector             | WD1793 @ $0310      |
| $C100   | CSPTBL | CSP routine jump table       | Same structure      |
| $C152   | COLD   | Cold start entry             | Init HW, boot p-machine |
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

### Layer 3: p-code interpreter (target $D000-$EFFF) - adaptation needed
Planned to be largely based on Apple II 6502 p-machine code, with Apple II-specific hardware/memory-banking behavior removed or adapted for Oric flat RAM and I/O.

### Layer 4: SYSTEM.PASCAL / p-code segments - portable
Compiler/editor/filer/library segments should run unchanged on a correct p-machine once the interpreter and BIOS are functional.

## Memory map (target / working assumptions)

```text
$0000-$00FF   Zero page (p-machine registers, BIOS/loader workspace)
$0100-$01FF   6502 stack (p-machine evaluation stack)
$0200-$02FF   Interpreter/workspace (boot loader currently linked at $0200)
$0300-$03FF   VIA 6522 I/O + Microdisc FDC registers
$0400-$04FF   Disk buffer / workspace
$0500-$97FF   User heap/code area (target)
$9800-$9FFF   Character sets
$A000-$BFDF   HIRES bitmap
$BB80-$BF3F   TEXT screen (40x28)
$C000-$CFFF   BIOS (loaded system image)
$D000-$EFFF   Interpreter/system code region (target)
$F000-$FFFF   ROM/overlay-dependent region (Microdisc overlay control involved)
```

Actual runtime layout and segment placement may evolve during bring-up.

## Oric hardware notes (key)

### VIA 6522 ($0300-$030F)
- Keyboard, printer, PSG access, timers/IRQ
- Timer 1 commonly used for system tick (~10ms)

### ULA / display
- Text screen: `$BB80-$BF3F` (40x28)
- Attribute bytes encoded in text stream (colors/modes/styles); code must preserve/handle attributes correctly

### Keyboard matrix
- Columns selected via VIA/PSG port A, row sense via VIA PB3

### Microdisc WD1793 FDC
- WD1793 register mapping as used by Microdisc/Oricutron: `$0310` command/status, `$0311` track, `$0312` sector, `$0313` data, `$0314` control, `$0318` DRQ status (bit 7; byte ready when 0 / DRQ asserted)
- Writing the track register does **not** seek; use a Seek command (target track in data register) and wait for BUSY to clear
- Overlay RAM/ROM control is critical during boot and disk I/O

## Microdisc ROM boot flow (critical - reverse engineered)

The Microdisc ROM (8KB at `$E000-$FFFF`) has its own boot sequence that is **not** compatible with Apple II-style chain-loading from sector 0. Understanding this is essential for creating a bootable p-System disk.

### ROM reset flow (high-level)

```text
RESET -> init hardware -> init I/O vectors
  -> display default boot message/screen
  -> read track 0, sector 1 to $C000
  -> validate/init checks (e.g. non-zero marker at $C013)
  -> search directory for "SYSTEMDOS"
    -> if found: load descriptor/data per ROM rules, set up vectors, execute payload
    -> if not found: remain in boot/error state
```

### Key facts (reference)

- ROM reads **track 0, sector 1** (not sector 0) to `$C000` via the Microdisc FDC.
- "Insert system disc" is the default boot screen until a valid `SYSTEMDOS` is found/loaded.
- Directory entries are 16 bytes starting at offset `$26` in the directory sector (Sedoric-style layout).
- Expected primary filename is `SYSTEMDOS` (BOOTUPCOM handling is ROM-specific; not required for our current strategy).
- Boot-sector/init checks require expected marker bytes to be non-zero (commonly including `$C013` in observed layouts); exact checks are ROM-specific.
- Descriptor/data-sector conventions and ROM vector behavior are subtle and ROM-specific; see format notes below and validate against ROM/Oricutron behavior.

## Sedoric file system format (reference)

The Sedoric format uses indirection for file storage (directory -> descriptor -> data sectors).

### Directory sector (256 bytes, typical)

```text
$00-$22 Header/reserved
$23-$24 Forward pointer (track, sector) for next directory sector (0,0 = last)
$25     File count in directory
$26+    16-byte entries:
  [0-8]  Filename (9 bytes, space-padded)
  [9-11] Extension/type bytes
  [12]   Descriptor sector
  [13]   Descriptor track
  [14]   Sector/count-related field (usage varies by implementation/context)
  [15]   Flags (e.g. $40 = UNPROT)
```

### Descriptor sector (256 bytes)

Contains forward pointer and block/data references (pairs of track/sector), plus metadata used by ROM loading/copy routines.

### Data sector (256 bytes) - count-group/copy format (ROM-dependent)

Data sectors can encode copy operations/count groups consumed by ROM routines, including destination/forward-pointer fields in sector header/metadata areas. Exact behavior is ROM-specific and was reverse engineered for this project.

**Important:** For this project, the authoritative implementation details are in `makedisk.py`, `src/boot/boot.asm`, and emulator/ROM behavior observed during debugging.

## Apple II differences to remove/adapt (interpreter/BIOS)

Examples of Apple II-specific behavior that must be removed or replaced:

| Apple II feature | Oric replacement |
| --- | --- |
| `$C000` KBD / `$C010` KBDSTRB | VIA/PSG keyboard matrix scan |
| `$C051/$C052/$C054/$C057` soft switches | ULA/text-hires attribute/control handling |
| `$C081/$C083/$C08B` LC banking | No LC banking (flat RAM model / overlay control differences) |
| `$C002/$C004` aux/main memory | No aux memory |
| Slot I/O (`$C0nX`) | Microdisc WD1793 registers (`$0310+`) |
| BIOS placement assumptions | Oric layout (`$C000` BIOS region in this port) |

## Debugging notes

- A useful local debugging approach is attaching `gdb` to Oricutron and inspecting emulator state (e.g. `struct machine`/CPU/memory) to diagnose freezes or illegal-opcode/JAM conditions.
- If the emulator enters `EM_DEBUG`, CPU execution may stop until mode is changed back to running (implementation-dependent; see Oricutron source).

## Reference documents

- Apple Pascal 1.3 p-machine source (annotated 6502 disassembly): `http://pascal.hansotten.com/uploads/ucsd/pcode/applepascalinterpreter%20PMACH13.TXT`
- P-Source guide (Hyde): `http://pascal.hansotten.com/uploads/ucsd/apple/ii/Hyde_P-Source-A%20Guide%20to%20the%20APPLE%20Pascal%20System_1983.pdf`
- UCSD p-System / UCSD Pascal Internal Architecture Guide: `http://pascal.hansotten.com/uploads/ucsd/softech/UCSD%20P-System%20&%20UCSD%20PASCAL_Internal_Architecture_Guide.pdf`
- Oric hardware wiki: `https://wiki.defence-force.org/index.php?title=Oric_hardware`
- Oric ULA notes: `http://www.defence-force.org/computing/oric/docs/ula.txt`
- Oricutron source: `https://github.com/pete-gordon/oricutron` (and local emulator sources when available)
