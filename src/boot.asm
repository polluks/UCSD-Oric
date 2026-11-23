.include "oric_hardware.i"

SYS_BASE    = $C000         ; first byte of the system image
COLD_START  = $C152         ; p-System cold start entry
SYS_SECTORS = 48            ; 12288 bytes = $C000-$EFFF (full BIOS+INTERP image)

; The Microdisc boot ROM uses much of page 2 ($0244, $024E/$024F, $0272/$0273,
; $02C0+) as scratch while loading SYSTEMDOS.  Only the short stub at $024A is
; safe; it jumps here, where the descriptor has already copied the real loader.
RELOC_ADDR  = $9000

; Loader workspace (zero page)
dstptr      = $F0           ; 2 bytes: destination pointer
curtrk      = $F2           ; current FDC track
track       = $F3           ; wanted track
sector      = $F4           ; wanted sector
pg          = $F5           ; current sector page base high byte ($C0 + idx)

        .segment "LOADER"

; The Microdisc boot ROM copies the SYSTEMDOS payload to $0200 but enters it
; through the fixed address $024A (the standard SYSTEMDOS entry offset).  The
; first $44 bytes are therefore a header.  $0244 must remain the ROM's IRQ
; trampoline ("JMP $EE22") because disk I/O during boot still uses it.
; makedisk.py copies the code after this stub to RELOC_ADDR before the ROM
; transfers control, since the rest of page 2 is ROM scratch.
        .repeat $44
        .byte   $EA
        .endrepeat
        .byte   $4C, $22, $EE      ; $0244: Microdisc IRQ trampoline
        .byte   $EA, $EA, $EA      ; $0247-$0249: alignment

        jmp     RELOC_ADDR         ; $024A: ROM enters SYSTEMDOS here

;-------------------------------------------------------------------------------
; Enable overlay RAM, disable the Microdisc ROM, keep MFM/double density
;-------------------------------------------------------------------------------
        sei
        cld
        lda     #FDC_CTRL_READY
        sta     FDC_CTRL
        sta     $0480           ; Sedoric's shadow copy

;-------------------------------------------------------------------------------
; Restore to track 0 and wait until the controller is idle
;-------------------------------------------------------------------------------
        lda     #0                      ; restore, 6 ms step rate
        sta     FDC_CMD
        sta     curtrk                  ; track register is reset by the controller itself
        ldy     #10
@d0:    dey
        bne     @d0                     ; wait ~50 us so BUSY has time to rise
@wait_restore:
        lda     FDC_STAT
        lsr                             ; carry = BUSY (bit 0)
        bcs     @wait_restore

;-------------------------------------------------------------------------------
; Destination = $C000, first sector = track 1 / sector 1
;-------------------------------------------------------------------------------
        lda     #1
        sta     track
        sta     sector
        lda     #$C0
        sta     pg

        ldx     #SYS_SECTORS

;-------------------------------------------------------------------------------
; Read one sector at a time into $C000 + (sector_index * 256)
;-------------------------------------------------------------------------------
@sector_loop:
        lda     track
        cmp     curtrk
        beq     @read
; ---- seek: data register = target track; leave the track register alone ----
        sta     FDC_DATA
        lda     #FDC_CMD_SEEK           ; $14 = seek with verify
        sta     FDC_CMD
        ldy     #10
@d1:    dey
        bne     @d1                     ; wait ~50 us so BUSY has time to rise
@wait_seek:
        lda     FDC_STAT
        lsr                             ; carry = BUSY (bit 0)
        bcs     @wait_seek
        and     #$08                    ; status bit 4 (seek error) >> 1
        bne     @fail
        lda     track
        sta     curtrk

@read:
        lda     #0
        sta     dstptr                  ; destination = page base, offset 0
        lda     pg
        sta     dstptr+1
        lda     sector
        sta     FDC_SEC
        lda     #FDC_CMD_READSEC        ; $80 = read sector
        sta     FDC_CMD
        ldy     #10
@d2:    dey
        bne     @d2                     ; ~50 us delay; leaves Y = 0
@byte_loop:
        lda     FDC_DRQ
        bpl     @got                    ; bit 7 = 0 -> byte ready
        lda     FDC_STAT
        lsr
        bcs     @byte_loop              ; still BUSY -> keep waiting
        bcc     @fail                   ; command ended without data -> error
@got:
        lda     FDC_DATA
        sta     (dstptr),y
        iny
        bne     @byte_loop
@wait_done:
        lda     FDC_STAT
        lsr
        bcs     @wait_done              ; wait until the command has finished
        and     #$0E                    ; $1C >> 1: lost data, CRC, record not found
        bne     @fail
        inc     pg                      ; next destination page
        inc     sector
        lda     sector
        cmp     #18                     ; sectors 1..17 per track
        bne     @next
        lda     #1
        sta     sector
        inc     track                   ; next track (seek happens at loop start)
@next:
        dex
        bne     @sector_loop
        jmp     COLD_START

@fail:
        lda     #'E'
        sta     $BB80                   ; top-left text cell shows an error marker
@fail_hold:
        bne     @fail_hold              ; A is 'E' (Z clear), so loop forever
