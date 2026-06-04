;===============================================================================
; Microdisc Boot Sector
; Loaded by the Microdisc ROM to $0100, then executed.
; Loads SYSTEM.ORIC from disk to memory and jumps to COLD_START ($C152).
;
; Disk layout:
;   Track 0, Sector 0: Boot sector (this code, 256 bytes)
;   Track 0, Sectors 1-17, Track 1, Sectors 1-...: SYSTEM.ORIC data
;
; The SYSTEM.ORIC data is stored in memory-mapped order (padded):
;   $C000-$CF8A: BIOS + BIOSDATA
;   $CF8B-$CFFF: zero-padded gap
;   $D000-$D70E: p-code interpreter
;===============================================================================

    .org    $0100

BOOT_START:
; Step 1: Disable interrupts
    sei

; Step 2: Initialize VIA and FDC
; Set VIA DDRA/DDRB to outputs (for FDC control)
    lda     #$FF
    sta     VIA_DDRB
    lda     #$0F
    sta     VIA_DDRA

; Disable ROM overlay -> RAM appears at $C000-$FFFF
; FDC control reg: MFM (bit3=0), clk div (bit2=1), ROM disable (bit1=0)
    lda     #$04
    sta     FDC_CTRL

; Step 3: Restore drive (seek track 0)
    lda     #FDC_CMD_RESTORE
    sta     FDC_STAT
@wait_restore:
    lda     FDC_STAT
    bmi     @wait_restore       ; bit 7 = busy

; Step 4: Set initial track/sector
    lda     #0
    sta     FDC_TRK
    lda     #1                  ; sector 1 (sector 0 is the boot sector)
    sta     FDC_SEC

; Step 5: Initialize destination pointer = $C000
    lda     #$00
    sta     $80                 ; low byte (used as ($80),y pointer)
    lda     #$C0
    sta     $81                 ; high byte

; Step 6: Read sector loop
@read_loop:
    lda     #FDC_CMD_READSEC
    sta     FDC_STAT

@wait_drq:
    lda     FDC_STAT
    lsr     a                   ; bit 0 -> carry (DRQ=1 when bit 0 set)
    bcc     @wait_drq

; Transfer 256 bytes from FDC_DATA to ($80),Y
    ldy     #0
@byte_loop:
    lda     FDC_DATA
    sta     ($80), y
    iny
    bne     @byte_loop

; Advance destination pointer by 256 bytes
    inc     $81

; Advance to next sector
    inc     FDC_SEC
    lda     FDC_SEC
    cmp     #18                 ; > 17 sectors on this track?
    bne     @check_done
    lda     #1
    sta     FDC_SEC
    inc     FDC_TRK

@check_done:
; Check if we've loaded all of SYSTEM.ORIC
; ROM is 16384 bytes (64 sectors), but only $C000-$D8BF is meaningful
; 25 sectors from $C000 = $D900, covering full CODE segment
    lda     $81
    cmp     #$D9
    bcc     @read_loop

; Step 7: All loaded — jump to cold start ($C152)
    jmp     $C152

; Pad to exactly 256 bytes
    .org    BOOT_START + 256
