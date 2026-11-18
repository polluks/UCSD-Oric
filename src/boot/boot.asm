.include "oric_hardware.i"

SYS_BASE    = $C000         ; first byte of the system image
COLD_START  = $C152         ; p-System cold start entry
SYS_SECTORS = 25            ; 6400 bytes = $C000-$D8FF

; Loader workspace (zero page)
dstptr      = $F0           ; 2 bytes: destination pointer
curtrk      = $F2           ; current FDC track
track       = $F3           ; wanted track
sector      = $F4           ; wanted sector
pg          = $F5           ; current sector page base high byte ($C0 + idx)

        .segment "LOADER"

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
        lda     #0
        sta     FDC_CMD
        sta     FDC_TRK
        sta     curtrk
@wait_restore:
        lda     FDC_STAT
        and     #$01            ; BUSY
        bne     @wait_restore

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
; The store uses absolute indexed addressing (STA $C000,Y) with a self
; patched high byte so each sector lands at its own page.
; The store instruction is: 99 00 C0  = STA $C000,Y  (at $0264, hi operand $0266)
;-------------------------------------------------------------------------------
@sector_loop:
        lda     track
        cmp     curtrk
        beq     @read
; ---- seek to the wanted track (data register = target, then SEEK) ----
        sta     FDC_DATA
        sta     FDC_TRK
        sta     curtrk
        lda     #FDC_CMD_SEEK
        sta     FDC_CMD
@wait_seek:
        lda     FDC_STAT
        and     #$01
        bne     @wait_seek

@read:
        lda     sector
        sta     FDC_SEC
        lda     #FDC_CMD_READSEC
        sta     FDC_CMD
        lda     pg
        sta     $025C           ; patch hi byte of STA $C000,Y ($025A) for this sector
        ldy     #0
@byte_loop:
        lda     FDC_DRQ
        bmi     @byte_loop      ; bit7 = 1 -> no byte ready yet
        lda     FDC_DATA
        sta     $C000,Y         ; base = ($C0+sector_index)*256 + Y
        iny
        bne     @byte_loop
        lda     FDC_STAT
        and     #$1C            ; lost data / CRC error / record not found
        bne     @fail
        inc     pg
        inc     sector
        cmp     #18
        bne     @next
        lda     #1
        sta     sector
        inc     track
        lda     #$C0
        sta     pg
@next:
        dex
        bne     @sector_loop
        jmp     COLD_START
@fail:
        jmp     COLD_START
