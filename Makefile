# Makefile for UCSD p-System Oric Port
# Uses cc65 toolchain (ca65, ld65)

AS      := ca65
LD      := ld65
CFLAGS  := -t none -I include
LDFLAGS := -C oric.cfg

OUTDIR  := out
TARGET  := $(OUTDIR)/SYSTEM.ORIC

# Source
MAIN_SRC := src/bios.asm

.PHONY: all clean disk

all: $(TARGET)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/bios.o: $(MAIN_SRC) include/*.i | $(OUTDIR)
	$(AS) $(CFLAGS) -o $@ $<

$(TARGET): $(OUTDIR)/bios.o oric.cfg | $(OUTDIR)
	$(LD) $(LDFLAGS) -o $@ $(OUTDIR)/bios.o --mapfile $(OUTDIR)/system.map

# Create disk image for Oricutron (simple flat disk)
disk: $(TARGET)
	@echo "Creating disk image..."
	dd if=/dev/zero of=$(OUTDIR)/oric_pascal.dsk bs=256 count=560 2>/dev/null
	dd if=$(TARGET) of=$(OUTDIR)/oric_pascal.dsk bs=256 seek=1 conv=notrunc 2>/dev/null
	@echo "Disk image: $(OUTDIR)/oric_pascal.dsk"
	@echo "Size: $$(wc -c < $(TARGET)) bytes"

# Clean
clean:
	rm -rf $(OUTDIR)

# Emulate with Oricutron
emul: disk
	oricutron $(OUTDIR)/oric_pascal.dsk

.PHONY: all clean disk emul
