# Makefile for UCSD p-System Oric Port
# Uses cc65 toolchain (ca65, ld65)

AS      := ca65
LD      := ld65
CFLAGS  := -t none -I include
LDFLAGS := -C oric.cfg
PY      := python3

OUTDIR  := out
LINKED  := $(OUTDIR)/SYSTEM.bin    # raw ld65 output
SYSIMG  := $(OUTDIR)/SYSTEM.ORIC   # 6400-byte system image (boot payload)
LOADER  := $(OUTDIR)/boot.bin      # boot loader, assembled at $0200
DSK     := $(OUTDIR)/SYSTEM.dsk    # bootable Microdisc image

.PHONY: all clean disk emul image

all: $(DSK)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/bios.o: src/bios.asm include/*.i | $(OUTDIR)
	$(AS) $(CFLAGS) -o $@ $<

$(LINKED): $(OUTDIR)/bios.o oric.cfg | $(OUTDIR)
	$(LD) $(LDFLAGS) -o $@ $(OUTDIR)/bios.o --mapfile $(OUTDIR)/system.map

$(SYSIMG): $(LINKED) build_image.py $(OUTDIR)/system.map
	$(PY) build_image.py

$(OUTDIR)/boot.o: src/boot/boot.asm include/*.i | $(OUTDIR)
	$(AS) $(CFLAGS) -o $@ $<

$(LOADER): $(OUTDIR)/boot.o src/boot/boot.cfg
	$(LD) -C src/boot/boot.cfg -o $@ $(OUTDIR)/boot.o

$(DSK): $(SYSIMG) $(LOADER) makedisk.py
	$(PY) makedisk.py

# Build the system image only
image: $(SYSIMG)

# Emulate with Oricutron
emul: $(DSK)
	oricutron -m atmos -k microdisc -d $(DSK)

# Clean
clean:
	rm -rf $(OUTDIR)
