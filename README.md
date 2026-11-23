# UCSD-Oric

Port of Apple II UCSD Pascal 1.3 (p-System) to the Oric-1/Atmos (6502, 48K RAM).

This repository contains early bring-up work for a Microdisc-bootable Oric build: a Sedoric-compatible disk image, a small SYSTEMDOS boot loader, and an in-progress BIOS/interpreter image built with the cc65 toolchain.

## Status

**Work in progress.** The project is under active development and not yet booting to a usable UCSD p-System environment.

Currently in the tree:
- Bootable **MFM_DISK** image generation for Oric Microdisc (`makedisk.py`)
- Sedoric-style boot structures (boot sector, directory, SYSTEMDOS descriptor)
- Microdisc boot loader (`src/boot.asm`) that loads the 48-sector system image from disk and jumps to COLD (`$C152`)
- Main system source and build pipeline (`src/bios.asm`, `src/oric.cfg`, `build_image.py`)
- UCSD p-System volume/directory (`ORIC:`) with system files on disk (`SYSTEM.PASCAL`, `COMPILER`, `EDITOR`, `FILER`, `LIBRARY`, `MISCINFO`, `CHARSET`, `SYNTAX`)
- Ongoing WD1793/Microdisc FDC, console/BIOS, and p-code/CSP bring-up work

Known issues / limitations:
- Boot/runtime on Oricutron is not yet end-to-end verified (headless runs have timed out without visible confirmation of COLD/banner)
- Many p-code opcodes and some CSP routines remain stubbed/best-effort
- p-code segment loading/runtime integration and end-to-end p-System functionality are not yet verified

For detailed architecture, memory layout, hardware notes, and Microdisc ROM boot analysis, see [`AGENTS.md`](AGENTS.md).

## Requirements

- [cc65](https://cc65.github.io/) toolchain: `ca65`, `ld65`
- Python 3
- [Oricutron](https://github.com/pete-gordon/oricutron) for emulation/testing (Microdisc support)

## Build

```sh
make
```

Build outputs are written to `out/`:

| File | Description |
| --- | --- |
| `boot.bin` | SYSTEMDOS boot loader (linked for `$0200`) |
| `SYSTEM.bin` | Linked BIOS/interpreter binary (ld65 output) |
| `SYSTEM.ORIC` | 12288-byte system image laid out for load at `$C000-$EFFF` (48 sectors) |
| `system.map` | Linker map |
| `SYSTEM.dsk` | Bootable Microdisc **MFM_DISK** image |

Useful targets:

```sh
make image   # build out/SYSTEM.ORIC only
make emul    # run: oricutron -m atmos -k microdisc -d out/SYSTEM.dsk
make clean   # remove out/
```

## Disk / boot notes

- The generated disk is an **MFM_DISK** image (the format expected by Oricutron for this setup).
- Boot uses the Microdisc ROM’s Sedoric/SYSTEMDOS flow (reads track 0, sector 1; locates `SYSTEMDOS`; loads its descriptor payload).
- Current strategy: the ROM loads a small loader to `$0200`; the loader reads 48 sectors (12288 bytes) of `SYSTEM.ORIC` from track 1 into `$C000-$EFFF` and jumps to `COLD` (`$C152`).
- The disk also contains a UCSD p-System volume/directory header (`ORIC:`) and copies of Apple II UCSD Pascal 1.3 system files: `SYSTEM.PASCAL`, `SYSTEM.COMPILER`, `SYSTEM.EDITOR`, `SYSTEM.FILER`, `SYSTEM.LIBRARY`, `SYSTEM.MISCINFO`, `SYSTEM.CHARSET`, `SYSTEM.SYNTAX` (from `ucsd/`, placed as UCSD file data starting at block 33). `SYSTEM.MISCINFO` is included with a best-effort Oric console adjustment (28-line screen height).
- No external `system.rom` is used by this project’s boot path.

## Repository layout

- `src/bios.asm` — BIOS/system code (ca65)
- `src/boot.asm` — Microdisc boot loader
- `src/boot.cfg` — ld65 config for the loader
- `src/include/oric_hardware.i` — Oric hardware definitions
- `src/include/pcode_constants.i` — p-code/p-machine constants
- `src/oric.cfg` — ld65 config for the main system image
- `build_image.py` — converts linked output into `out/SYSTEM.ORIC`
- `makedisk.py` — builds `out/SYSTEM.dsk` (MFM_DISK, Sedoric + UCSD structures)
- `ucsd/` — Apple II UCSD Pascal 1.3 system files copied onto the UCSD volume
- `Makefile` — build rules
- `AGENTS.md` — detailed porting notes and references

## References

- UCSD p-System / Apple Pascal interpreter and architecture material (links in [`AGENTS.md`](AGENTS.md))
- Oric hardware and ULA documentation (links in [`AGENTS.md`](AGENTS.md))
- [Oricutron](https://github.com/pete-gordon/oricutron) emulator source/behavior
