# Makefile for UCSD p-System Oric Port
# Uses cc65 toolchain (ca65, ld65)

AS      := ca65
LD      := ld65
CFLAGS  := -t none -I include
LDFLAGS := -C oric.cfg
PY      := python3

OUTDIR  := out
TARGET  := $(OUTDIR)/SYSTEM.ORIC
ROM     := $(OUTDIR)/system.rom
DSK     := $(OUTDIR)/system.dsk

# Source
MAIN_SRC := src/bios.asm

.PHONY: all clean disk emul rom

all: $(DSK)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/bios.o: $(MAIN_SRC) include/*.i | $(OUTDIR)
	$(AS) $(CFLAGS) -o $@ $<

$(TARGET): $(OUTDIR)/bios.o oric.cfg | $(OUTDIR)
	$(LD) $(LDFLAGS) -o $@ $(OUTDIR)/bios.o --mapfile $(OUTDIR)/system.map

# Post-process linker output into 16KB flat ROM image
$(ROM): $(TARGET) post_process.py
	$(PY) post_process.py

# Create bootable Microdisc disk image (boot sector + system data)
$(DSK): $(ROM) makedisk.py
	$(PY) makedisk.py

# Build ROM only
rom: $(ROM)

# Emulate with Oricutron
emul: $(DSK)
	oricutron $(DSK)

# Clean
clean:
	rm -rf $(OUTDIR)
