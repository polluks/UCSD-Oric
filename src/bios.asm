; SYSTEM.ORIC - UCSD p-System for Oric-1/Atmos
; For ca65 assembler
;
; Memory: $C000-$CFFF BIOS, $D000-$EFFF interpreter

.include "oric_hardware.i"

; Segment offsets (address - $C000)
OFS_DWRITE = $0000
OFS_DREAD  = $0003
OFS_CSPTBL = $0100
OFS_COLD   = $0152
OFS_CONCK  = $0899
OFS_CINIT  = $09F8
OFS_PINIT  = $0A27
OFS_GRINIT = $0A3F
OFS_DINIT  = $0A84
OFS_CWRITE = $0A9F
OFS_PWRITE = $0AD1
OFS_CREAD  = $0B3B
OFS_CSTAT  = $0BCA
OFS_DSTAT  = $0C68
OFS_HANDLERS = $0D00

;===============================================================================
; BIOS segment ($C000-$CFFF)
;===============================================================================
.segment "BIOS"

.export COLD_START, MAINLOOP

;===============================================================================
; $C000: DWRITE - Disk write sector 
;===============================================================================
    jmp     disk_write

;===============================================================================
; $C003: DREAD - Disk read sector
;===============================================================================
    jmp     disk_read

; Pad to $C100 (offset $0100): 256 - 6 = 250 bytes
    .res    OFS_CSPTBL - OFS_DREAD - 3, $EA

;===============================================================================
; $C100: CSPTBL - CSP routine jump table (35 entries = 70 bytes)
;===============================================================================
CSPTBL:
    .addr   csp_ioc         ; 0  IOC
    .addr   csp_new         ; 1  NEW
    .addr   csp_unimpl      ; 2  MVL
    .addr   csp_unimpl      ; 3  MVR
    .addr   csp_exit        ; 4  EXIT
    .addr   csp_uread       ; 5  UREAD
    .addr   csp_uwrite      ; 6  UWRITE
    .addr   csp_unimpl      ; 7  IDS
    .addr   csp_unimpl      ; 8  TRS
    .addr   csp_tim         ; 9  TIM
    .addr   csp_flc         ; 10 FLC
    .addr   csp_unimpl      ; 11 SCN
    .addr   csp_ustat       ; 12 USTAT
    .addr   0               ; 13
    .addr   0               ; 14
    .addr   csp_lds         ; 15 LDS
    .addr   csp_unimpl      ; 16 ULS
    .addr   csp_tnc         ; 17 TNC
    .addr   csp_rnd         ; 18 RND
    .addr   csp_unimpl      ; 19 SIN
    .addr   csp_unimpl      ; 20 COS
    .addr   csp_unimpl      ; 21 LOG
    .addr   csp_unimpl      ; 22 ATAN
    .addr   csp_unimpl      ; 23 LN
    .addr   csp_unimpl      ; 24 EXP
    .addr   csp_unimpl      ; 25 SQRT
    .addr   csp_mrk         ; 26 MRK
    .addr   csp_rls         ; 27 RLS
    .addr   csp_ior         ; 28 IOR
    .addr   csp_ubusy       ; 29 UBUSY
    .addr   csp_unimpl      ; 30 POT
    .addr   csp_uwait       ; 31 UWAIT
    .addr   csp_uclr        ; 32 UCLR
    .addr   csp_hlt         ; 33 HLT
    .addr   csp_memav       ; 34 MEMAV

; CSPTBL ends at offset $C146. Pad 12 bytes to $C152.
csp_unimpl:
    rts
    .res    11, $EA

;===============================================================================
; $C152: COLD - Cold start entry
;===============================================================================
COLD_START:
    ldx     #$FF
    txs
    lda     #$FF
    sta     VIA_DDRB
    lda     #$0F
    sta     VIA_DDRA
    jsr     con_init
    ldx     #0
@msg_loop:
    lda     welcome_msg, x
    beq     @msg_done
    jsr     con_write
    inx
    bne     @msg_loop
@msg_done:
    jsr     disk_init
    lda     #0
    sta     BASE
    sta     BASE+1
    sta     MP
    sta     MP+1
    lda     #<boot_pcode
    sta     IPC
    lda     #>boot_pcode
    sta     IPC+1
    lda     #<HEAP_START
    sta     NP
    lda     #>HEAP_START
    sta     NP+1
    lda     #<RAM_TOP
    sta     KP
    lda     #>RAM_TOP
    sta     KP+1
    jmp     MAINLOOP

welcome_msg:
    .byte   $0D
    .byte   "UCSD Pascal Oric Port 1.3", $0D, $0D
    .byte   0

; Pad to $C899 (offset $0899)
; Current offset = OFS_COLD + (current - COLD_START)
; But COLD_START is at OFS_COLD ($0152) + some bytes
; Message takes ~36 bytes, code ~35, total cold ~71 = $47
; So current offset ~ $0152 + $47 = $0199
; Padding needed = $0899 - $0199 = $0700
    .res    $0700, $EA

;===============================================================================
; $C899: CONCK - Console check
;===============================================================================
CONCK_ENTRY:
    jmp     con_check

    .res    OFS_CINIT - OFS_CONCK - 3, $EA

;===============================================================================
; $C9F8: CINIT - Console init
;===============================================================================
CINIT_ENTRY:
    jmp     con_init

    .res    OFS_PINIT - OFS_CINIT - 3, $EA

;===============================================================================
; $CA27: PINIT - Printer init
;===============================================================================
PINIT_ENTRY:
    jmp     pr_init

    .res    OFS_GRINIT - OFS_PINIT - 3, $EA

;===============================================================================
; $CA3F: GRINIT - Graphics init
;===============================================================================
GRINIT_ENTRY:
    jmp     gr_init

    .res    OFS_DINIT - OFS_GRINIT - 3, $EA

;===============================================================================
; $CA84: DINIT - Disk init
;===============================================================================
DINIT_ENTRY:
    jmp     disk_init

    .res    OFS_CWRITE - OFS_DINIT - 3, $EA

;===============================================================================
; $CA9F: CWRITE - Console write
;===============================================================================
CWRITE_ENTRY:
    jmp     con_write

    .res    OFS_PWRITE - OFS_CWRITE - 3, $EA

;===============================================================================
; $CAD1: PWRITE - Printer write
;===============================================================================
PWRITE_ENTRY:
    jmp     pr_write

    .res    OFS_CREAD - OFS_PWRITE - 3, $EA

;===============================================================================
; $CB3B: CREAD - Console read
;===============================================================================
CREAD_ENTRY:
    jmp     con_read

    .res    OFS_CSTAT - OFS_CREAD - 3, $EA

;===============================================================================
; $CBCA: CSTAT - Console status
;===============================================================================
CSTAT_ENTRY:
    jmp     con_status

    .res    OFS_DSTAT - OFS_CSTAT - 3, $EA

;===============================================================================
; $CC68: DSTAT - Disk status
;===============================================================================
DSTAT_ENTRY:
    jmp     disk_status

; Pad to $CD00 (real handler code area)
    .res    OFS_HANDLERS - OFS_DSTAT - 3, $EA

;===============================================================================
; Actual BIOS handler implementations at $CD00
;===============================================================================

; Text video address calculation
; Input: con_currow (0-27), con_curcol (0-39)
; Output: con_ptr = TEXT_SCREEN + row*40 + col
calc_video_addr:
    lda     con_currow
    asl     a
    asl     a
    sta     con_tmp
    asl     a
    asl     a
    asl     a
    clc
    adc     con_tmp
    sta     con_ptr
    lda     con_currow
    lsr     a
    lsr     a
    lsr     a
    lsr     a
    lsr     a
    sta     con_ptr+1
    clc
    lda     con_curcol
    adc     con_ptr
    sta     con_ptr
    bcc     :+
    inc     con_ptr+1
:   clc
    lda     #>TEXT_SCREEN
    adc     con_ptr+1
    sta     con_ptr+1
    ldy     #0
    rts

;===============================================================================
; con_init - Initialize console
;===============================================================================
con_init:
    lda     #$20
    ldx     #0
:   sta     TEXT_SCREEN, x
    sta     TEXT_SCREEN+256, x
    sta     TEXT_SCREEN+512, x
    sta     TEXT_SCREEN+768, x
    inx
    bne     :-
    ldx     #$3F
:   sta     TEXT_SCREEN+1024-64, x
    dex
    bpl     :-
    lda     #$00 | COLOR_WHITE
    sta     TEXT_SCREEN
    lda     #$10 | COLOR_BLACK
    sta     TEXT_SCREEN+1
    lda     #0
    sta     con_curcol
    sta     con_currow
    sta     kbd_wptr
    sta     kbd_rptr
    sta     kbd_count

    ; Initialize VIA for keyboard scanning
    lda     #$FF
    sta     VIA_DDRA           ; Port A = all outputs (PSG data bus)
    lda     VIA_DDRB
    ora     #$07               ; PB0-2 = outputs (column select)
    and     #$F7               ; PB3 = input (key sense)
    sta     VIA_DDRB
    lda     #AY_PCR_INACTIVE
    sta     VIA_PCR            ; CA2=0, CB2=0 (PSG inactive)
    rts

;===============================================================================
; con_write - Write character to console
; Entry: A = character
;===============================================================================
con_write:
    cmp     #$8D
    beq     @cr
    cmp     #$0D
    beq     @cr
    cmp     #$0A
    beq     @lf
    cmp     #$08
    beq     @bs
    cmp     #$20
    bcc     @done
    and     #$7F
    jsr     calc_video_addr
    sta     (con_ptr), y
    inc     con_curcol
    lda     con_curcol
    cmp     #40
    bne     @done
    lda     #0
    sta     con_curcol
    inc     con_currow
    lda     con_currow
    cmp     #28
    bne     @done
    dec     con_currow
    jsr     scroll_up
    rts
@cr:
    lda     #0
    sta     con_curcol
    rts
@lf:
    inc     con_currow
    lda     con_currow
    cmp     #28
    bne     @done
    dec     con_currow
    jsr     scroll_up
@done:
    rts
@bs:
    dec     con_curcol
    bpl     @done
    lda     #39
    sta     con_curcol
    dec     con_currow
    bpl     @done
    lda     #0
    sta     con_currow
    rts

;===============================================================================
; scroll_up
;===============================================================================
scroll_up:
    ldx     #0
:   lda     TEXT_SCREEN+40, x
    sta     TEXT_SCREEN, x
    lda     TEXT_SCREEN+40+256, x
    sta     TEXT_SCREEN+256, x
    lda     TEXT_SCREEN+40+512, x
    sta     TEXT_SCREEN+512, x
    lda     TEXT_SCREEN+40+768, x
    sta     TEXT_SCREEN+768, x
    inx
    bne     :-
    lda     #$20
    ldx     #39
:   sta     TEXT_SCREEN+1080, x
    dex
    bpl     :-
    rts

;===============================================================================
; con_check - Console check (CONCK)
;===============================================================================
con_check:
    jsr     con_status
    beq     @no_key
    jsr     con_read
    rts
@no_key:
    lda     #0
    rts

;===============================================================================
; con_read - Console read (CREAD)
;===============================================================================
con_read:
    lda     kbd_count
    bne     @get_buf
@wait:
    jsr     scan_kbd
    bcc     @wait
    ldx     kbd_wptr
    sta     kbd_buf, x
    inx
    txa
    and     #$3F
    sta     kbd_wptr
    inc     kbd_count
@get_buf:
    sei
    ldx     kbd_rptr
    lda     kbd_buf, x
    inx
    txa
    and     #$3F
    sta     kbd_rptr
    dec     kbd_count
    cli
    ora     #$80
    rts

;===============================================================================
; con_status - Console status (CSTAT)
;===============================================================================
con_status:
    lda     kbd_count
    bne     @ready
    jsr     scan_kbd
    bcc     @no_key
    ldx     kbd_wptr
    sta     kbd_buf, x
    inx
    txa
    and     #$3F
    sta     kbd_wptr
    inc     kbd_count
@ready:
    lda     #$FF
    rts
@no_key:
    lda     #0
    rts

;===============================================================================
; scan_kbd - Keyboard matrix scan (stub to CODE segment)
;===============================================================================
scan_kbd:
    jmp     scan_kbd_full

;===============================================================================
; disk_init
;===============================================================================
disk_init:
    lda     #FDC_ROMDIS
    sta     FDC_CTRL
    lda     #$D0
    sta     FDC_STAT
    ldx     #$FF
:   dex
    bne     :-
    lda     #$03
    sta     FDC_STAT
    rts

;===============================================================================
; disk_read, disk_write, disk_status
;===============================================================================
disk_read:
    clc
    rts

disk_write:
    clc
    rts

disk_status:
    lda     FDC_STAT
    ldx     #0
    clc
    rts

;===============================================================================
; pr_init, pr_write (printer)
;===============================================================================
pr_init:
    lda     #$FF
    sta     VIA_DDRA
    lda     #$10
    sta     VIA_DDRB
    rts

pr_write:
    pha
    sta     VIA_ORA
    lda     VIA_ORB
    and     #$EF
    sta     VIA_ORB
    nop
    nop
    lda     VIA_ORB
    ora     #$10
    sta     VIA_ORB
    ldx     #$10
:   dex
    bne     :-
    pla
    rts

;===============================================================================
; gr_init (graphics)
;===============================================================================
gr_init:
    lda     #$18 | $01
    sta     TEXT_SCREEN
    lda     #0
    ldx     #0
:   sta     HIRES_SCREEN, x
    sta     HIRES_SCREEN+256, x
    sta     HIRES_SCREEN+512, x
    sta     HIRES_SCREEN+768, x
    sta     HIRES_SCREEN+1024, x
    sta     HIRES_SCREEN+1280, x
    sta     HIRES_SCREEN+1536, x
    sta     HIRES_SCREEN+1792, x
    inx
    bne     :-
    ldx     #0
:   sta     HIRES_SCREEN+2048, x
    sta     HIRES_SCREEN+2304, x
    sta     HIRES_SCREEN+2560, x
    sta     HIRES_SCREEN+2816, x
    sta     HIRES_SCREEN+3072, x
    sta     HIRES_SCREEN+3328, x
    sta     HIRES_SCREEN+3584, x
    sta     HIRES_SCREEN+3840, x
    sta     HIRES_SCREEN+4096, x
    sta     HIRES_SCREEN+4352, x
    sta     HIRES_SCREEN+4608, x
    sta     HIRES_SCREEN+4864, x
    sta     HIRES_SCREEN+5120, x
    sta     HIRES_SCREEN+5376, x
    sta     HIRES_SCREEN+5632, x
    sta     HIRES_SCREEN+5888, x
    sta     HIRES_SCREEN+6144, x
    sta     HIRES_SCREEN+6400, x
    sta     HIRES_SCREEN+6656, x
    sta     HIRES_SCREEN+6912, x
    sta     HIRES_SCREEN+7168, x
    sta     HIRES_SCREEN+7424, x
    sta     HIRES_SCREEN+7680, x
    inx
    bne     :-
    rts

;===============================================================================
; Zero page variables
;===============================================================================
.zeropage
con_ptr:    .res 2
int_tmp:    .res 2
int_ptr:    .res 2
int_tmp2:   .res 2
int_ptr2:   .res 2

; BIOS data segment
.segment "BIOSDATA"
con_curcol: .res 1
con_currow: .res 1
con_tmp:    .res 1
kbd_buf:    .res 64
kbd_wptr:   .res 1
kbd_rptr:   .res 1
kbd_count:  .res 1
kbd_shift:  .res 1
kbd_col:    .res 1
kbd_row:    .res 1

;===============================================================================
; p-code Interpreter at $D000
;===============================================================================
.segment "CODE"

;===============================================================================
; JMPTBL - p-code instruction jump table ($D000-$D0FF)
;===============================================================================
JMPTBL:
    .addr P_ABI,  P_ABR,  P_ADI,  P_ADR
    .addr P_LAND, P_DIF,  P_DVI,  P_DVR
    .addr P_CHK,  P_FLO,  P_FLT,  P_INN
    .addr P_INT,  P_LOR,  P_MODI, P_MPI
    .addr P_MPR,  P_NGI,  P_NGR,  P_LNOT
    .addr P_SRS,  P_SBI,  P_SBR,  P_SGS
    .addr P_SQI,  P_SQR,  P_STO,  P_IXS
    .addr P_UNI,  P_LDE,  P_CSP,  P_LDCN
    .addr P_ADJ,  P_FJP,  P_INC,  P_IND
    .addr P_IXA,  P_LAO,  P_LSA,  P_LAE
    .addr P_MOV,  P_LDO,  P_SAS,  P_SRO
    .addr P_XJP,  P_RNP,  P_CIP,  P_EQU
    .addr P_GEQ,  P_GRT,  P_LDA,  P_LDC
    .addr P_LEQ,  P_LES,  P_LOD,  P_NEQ
    .addr P_STR,  P_UJP,  P_LDP,  P_STP
    .addr P_LDM,  P_STM,  P_LDB,  P_STB
    .addr P_IXP,  P_RBP,  P_CBP,  P_EQUI
    .addr P_GEQI, P_GTRI, P_LLA,  P_LDCI
    .addr P_LEQI, P_LESI, P_LDL,  P_NEQI
    .addr P_STL,  P_CXP,  P_CLP,  P_CGP
    .addr P_LPA,  P_STE,  P_NOP,  P_EFJ
    .addr P_NFJ,  P_BPT,  P_XIT,  P_NOP2
    .addr P_SLDL, P_SLDL, P_SLDL, P_SLDL
    .addr P_SLDL, P_SLDL, P_SLDL, P_SLDL
    .addr P_SLDL, P_SLDL, P_SLDL, P_SLDL
    .addr P_SLDL, P_SLDL, P_SLDL, P_SLDL
    .addr P_SLDO, P_SLDO, P_SLDO, P_SLDO
    .addr P_SLDO, P_SLDO, P_SLDO, P_SLDO
    .addr P_SLDO, P_SLDO, P_SLDO, P_SLDO
    .addr P_SLDO, P_SLDO, P_SLDO, P_SLDO
    .addr P_SIND0, P_SIND1, P_SIND2, P_SIND3
    .addr P_SIND4, P_SIND5, P_SIND6, P_SIND7

;===============================================================================
; MAINLOOP - Main p-code dispatch
;===============================================================================
MAINLOOP:
    ldy     #0
    lda     (IPC), y
    bpl     do_SLDC
    asl     a
    tax
    lda     JMPTBL+1, x
    pha
    lda     JMPTBL, x
    pha
    inc     IPC
    bne     :+
    inc     IPC+1
:   rts

do_SLDC:
    tax
    tya
    pha
    txa
    pha
    inc     IPC
    bne     :+
    inc     IPC+1
:   jmp     MAINLOOP

;===============================================================================
; P_SLDL - Short Load Local ($D8-$E7)
;===============================================================================
P_SLDL:
    pla
    sta     int_tmp
    pla
    sta     int_tmp+1
    sec
    lda     int_tmp
    sbc     #<JMPTBL
    lda     int_tmp+1
    sbc     #>JMPTBL
    lsr     a
    sec
    sbc     #$D8 - $80
    asl     a
    clc
    adc     #12
    tay
    lda     (MP), y
    pha
    dey
    lda     (MP), y
    pha
    jmp     MAINLOOP

;===============================================================================
; P_SLDO - Short Load Global ($E8-$F7)
;===============================================================================
P_SLDO:
    pla
    sta     int_tmp
    pla
    sta     int_tmp+1
    sec
    lda     int_tmp
    sbc     #<JMPTBL
    lda     int_tmp+1
    sbc     #>JMPTBL
    lsr     a
    sec
    sbc     #$E8 - $80
    asl     a
    clc
    adc     #12
    tay
    lda     (BASE), y
    pha
    dey
    lda     (BASE), y
    pha
    jmp     MAINLOOP

;===============================================================================
; LDCN - Load Constant NIL
;===============================================================================
P_LDCN:
    lda     #0
    pha
    pha
    jmp     MAINLOOP

;===============================================================================
; FJP - False Jump
;===============================================================================
P_FJP:
    pla
    and     #1
    beq     @do_jump
    pla
    jmp     MAINLOOP
@do_jump:
    pla
    jmp     do_UJP

;===============================================================================
; UJP - Unconditional Jump (+ do_UJP)
;===============================================================================
P_UJP:
do_UJP:
    ldy     #0
    lda     (IPC), y
    bmi     @jt_jump
    clc
    adc     IPC
    sta     IPC
    bcc     :+
    inc     IPC+1
:   jmp     MAINLOOP
@jt_jump:
    and     #$7F
    asl     a
    tay
    lda     (JTAB), y
    sta     int_tmp
    iny
    lda     (JTAB), y
    sta     int_tmp+1
    sec
    lda     int_tmp
    sbc     JTAB
    sta     IPC
    lda     int_tmp+1
    sbc     JTAB+1
    sta     IPC+1
    jmp     MAINLOOP

;===============================================================================
; LDCI - Load Integer Constant
;===============================================================================
P_LDCI:
    ldy     #1
    lda     (IPC), y
    pha
    dey
    lda     (IPC), y
    pha
    clc
    lda     IPC
    adc     #2
    sta     IPC
    bcc     :+
    inc     IPC+1
:   jmp     MAINLOOP

;===============================================================================
; CSP - Call Standard Procedure
;===============================================================================
P_CSP:
    ldy     #0
    lda     (IPC), y
    asl     a
    tax
    lda     #>csp_return
    pha
    lda     #<csp_return
    pha
    lda     $C101, x
    pha
    lda     $C100, x
    pha
    inc     IPC
    bne     :+
    inc     IPC+1
:   rts

csp_return:
    jmp     MAINLOOP

;===============================================================================
; ADI - Add Integers
;===============================================================================
P_ADI:
    pla
    sta     int_tmp
    pla
    sta     int_tmp+1
    pla
    clc
    adc     int_tmp
    sta     int_tmp
    pla
    adc     int_tmp+1
    pha
    lda     int_tmp
    pha
    jmp     MAINLOOP

;===============================================================================
; SBI - Subtract Integers
;===============================================================================
P_SBI:
    pla
    sta     int_tmp
    pla
    sta     int_tmp+1
    pla
    sec
    sbc     int_tmp
    sta     int_tmp
    pla
    sbc     int_tmp+1
    pha
    lda     int_tmp
    pha
    jmp     MAINLOOP

;===============================================================================
; MPI - Multiply Integers
;===============================================================================
P_MPI:
    jsr     mul16
    jmp     MAINLOOP

;===============================================================================
; DVI - Divide Integers
;===============================================================================
P_DVI:
    jsr     div16
    jmp     MAINLOOP

;===============================================================================
; MODI - Modulo Integers
;===============================================================================
P_MODI:
    jsr     div16
    pha
    tya
    pha
    jmp     MAINLOOP

;===============================================================================
; NGI - Negate Integer
;===============================================================================
P_NGI:
    pla
    eor     #$FF
    clc
    adc     #1
    sta     int_tmp
    pla
    eor     #$FF
    adc     #0
    pha
    lda     int_tmp
    pha
    jmp     MAINLOOP

;===============================================================================
; STO - Store Indirect Word
;===============================================================================
P_STO:
    pla
    sta     int_tmp
    pla
    sta     int_tmp+1
    pla
    sta     int_ptr
    pla
    sta     int_ptr+1
    lda     int_tmp
    ldy     #0
    sta     (int_ptr), y
    lda     int_tmp+1
    iny
    sta     (int_ptr), y
    jmp     MAINLOOP

;===============================================================================
; LDO - Load Global Word
;===============================================================================
P_LDO:
    jsr     get_big
    clc
    tya
    adc     BASE
    sta     int_ptr
    txa
    adc     BASE+1
    sta     int_ptr+1
    ldy     #11
    lda     (int_ptr), y
    pha
    dey
    lda     (int_ptr), y
    pha
    jmp     MAINLOOP

;===============================================================================
; SRO - Store Global Word
;===============================================================================
P_SRO:
    jsr     get_big
    clc
    tya
    adc     BASE
    sta     int_ptr
    txa
    adc     BASE+1
    sta     int_ptr+1
    pla
    ldy     #0
    sta     (int_ptr), y
    pla
    iny
    sta     (int_ptr), y
    jmp     MAINLOOP

;===============================================================================
; LAO - Load Global Address
;===============================================================================
P_LAO:
    jsr     get_big
    clc
    tya
    adc     #10
    pha
    txa
    adc     BASE+1
    pha
    lda     #0
    pha
    jmp     MAINLOOP

;===============================================================================
; LDL - Load Local Word
;===============================================================================
P_LDL:
    jsr     get_big
    clc
    tya
    adc     MP
    sta     int_ptr
    txa
    adc     MP+1
    sta     int_ptr+1
    ldy     #11
    lda     (int_ptr), y
    pha
    dey
    lda     (int_ptr), y
    pha
    jmp     MAINLOOP

;===============================================================================
; STL - Store Local Word
;===============================================================================
P_STL:
    jsr     get_big
    clc
    tya
    adc     MP
    sta     int_ptr
    txa
    adc     MP+1
    sta     int_ptr+1
    pla
    ldy     #0
    sta     (int_ptr), y
    pla
    iny
    sta     (int_ptr), y
    jmp     MAINLOOP

;===============================================================================
; CXP - Call External Procedure
;===============================================================================
P_CXP:
    jmp     MAINLOOP

;===============================================================================
; CGP - Call Global Procedure
;===============================================================================
P_CGP:
    jmp     MAINLOOP

;===============================================================================
; RNP - Return Non-Base Procedure
;===============================================================================
P_RNP:
    jmp     MAINLOOP

;===============================================================================
; RBP - Return Base Procedure
;===============================================================================
P_RBP:
    jmp     MAINLOOP

;===============================================================================
; MOV - Move Words
;===============================================================================
P_MOV:
    jmp     MAINLOOP

;===============================================================================
; Integer comparisons
;===============================================================================
P_EQUI:
    jsr     cmp16
    beq     @true
    lda     #0
    pha
    pha
    jmp     MAINLOOP
@true:
    lda     #1
    pha
    lda     #0
    pha
    jmp     MAINLOOP

P_NEQI:
    jsr     cmp16
    bne     @true
    lda     #0
    pha
    pha
    jmp     MAINLOOP
@true:
    lda     #1
    pha
    lda     #0
    pha
    jmp     MAINLOOP

P_LESI:
    jsr     cmp16_signed
    bmi     @true
    lda     #0
    pha
    pha
    jmp     MAINLOOP
@true:
    lda     #1
    pha
    lda     #0
    pha
    jmp     MAINLOOP

P_LEQI:
    jsr     cmp16_signed
    bmi     @true
    beq     @true
    lda     #0
    pha
    pha
    jmp     MAINLOOP
@true:
    lda     #1
    pha
    lda     #0
    pha
    jmp     MAINLOOP

P_GTRI:
    jsr     cmp16_signed
    bpl     @true
    beq     @false
@true:
    lda     #1
    pha
    lda     #0
    pha
    jmp     MAINLOOP
@false:
    lda     #0
    pha
    pha
    jmp     MAINLOOP

P_GEQI:
    jsr     cmp16_signed
    bpl     @true
    lda     #0
    pha
    pha
    jmp     MAINLOOP
@true:
    lda     #1
    pha
    lda     #0
    pha
    jmp     MAINLOOP

;===============================================================================
; NOP, BPT, XIT
;===============================================================================
P_NOP:
P_NOP2:
    jmp     MAINLOOP
P_BPT:
    jmp     MAINLOOP
P_XIT:
    jmp     COLD_START

;===============================================================================
; Stub opcodes
;===============================================================================
P_ABI:  jmp     MAINLOOP
P_ABR:  jmp     MAINLOOP
P_ADR:  jmp     MAINLOOP
P_LAND: jmp     MAINLOOP
P_DIF:  jmp     MAINLOOP
P_DVR:  jmp     MAINLOOP
P_CHK:  jmp     MAINLOOP
P_FLO:  jmp     MAINLOOP
P_FLT:  jmp     MAINLOOP
P_INN:  jmp     MAINLOOP
P_INT:  jmp     MAINLOOP
P_LOR:  jmp     MAINLOOP
P_MPR:  jmp     MAINLOOP
P_NGR:  jmp     MAINLOOP
P_LNOT: jmp     MAINLOOP
P_SRS:  jmp     MAINLOOP
P_SBR:  jmp     MAINLOOP
P_SGS:  jmp     MAINLOOP
P_SQI:  jmp     MAINLOOP
P_SQR:  jmp     MAINLOOP
P_IXS:  jmp     MAINLOOP
P_UNI:  jmp     MAINLOOP
P_LDE:  jmp     MAINLOOP
P_ADJ:  jmp     MAINLOOP
P_LSA:  jmp     MAINLOOP
P_LAE:  jmp     MAINLOOP
P_SAS:  jmp     MAINLOOP
P_LDP:  jmp     MAINLOOP
P_STP:  jmp     MAINLOOP
P_LDM:  jmp     MAINLOOP
P_STM:  jmp     MAINLOOP
P_LDB:  jmp     MAINLOOP
P_STB:  jmp     MAINLOOP
P_IXP:  jmp     MAINLOOP
P_CIP:  jmp     MAINLOOP
P_CLP:  jmp     MAINLOOP
P_CBP:  jmp     MAINLOOP
P_LDC:  jmp     MAINLOOP
P_EQU:  jmp     MAINLOOP
P_GEQ:  jmp     MAINLOOP
P_GRT:  jmp     MAINLOOP
P_LEQ:  jmp     MAINLOOP
P_LES:  jmp     MAINLOOP
P_NEQ:  jmp     MAINLOOP
P_LOD:  jmp     MAINLOOP
P_STR:  jmp     MAINLOOP
P_LDA:  jmp     MAINLOOP
P_IXA:  jmp     MAINLOOP
P_INC:  jmp     MAINLOOP
P_IND:  jmp     MAINLOOP
P_XJP:  jmp     MAINLOOP
P_LPA:  jmp     MAINLOOP
P_STE:  jmp     MAINLOOP
P_EFJ:  jmp     MAINLOOP
P_NFJ:  jmp     MAINLOOP
P_SIND0: jmp    MAINLOOP
P_SIND1: jmp    MAINLOOP
P_SIND2: jmp    MAINLOOP
P_SIND3: jmp    MAINLOOP
P_SIND4: jmp    MAINLOOP
P_SIND5: jmp    MAINLOOP
P_SIND6: jmp    MAINLOOP
P_SIND7: jmp    MAINLOOP
P_LLA:  jmp     MAINLOOP

;===============================================================================
; cmp16 - 16-bit unsigned comparison
;===============================================================================
cmp16:
    pla
    sta     int_tmp
    pla
    sta     int_tmp+1
    pla
    sec
    sbc     int_tmp
    sta     int_ptr
    pla
    sbc     int_tmp+1
    ora     int_ptr
    rts

;===============================================================================
; cmp16_signed - 16-bit signed comparison
;===============================================================================
cmp16_signed:
    pla
    sta     int_tmp
    pla
    sta     int_tmp+1
    pla
    sec
    sbc     int_tmp
    tay
    pla
    sbc     int_tmp+1
    bvc     :+
    eor     #$80
:   rts

;===============================================================================
; mul16 - 16x16 multiply
;===============================================================================
mul16:
    pla
    sta     int_tmp
    pla
    sta     int_tmp+1
    pla
    sta     int_ptr
    pla
    sta     int_ptr+1
    lda     #0
    sta     int_tmp2
    sta     int_tmp2+1
    ldx     #16
:   asl     int_tmp2
    rol     int_tmp2+1
    asl     int_tmp
    rol     int_tmp+1
    bcc     :+
    clc
    lda     int_tmp2
    adc     int_ptr
    sta     int_tmp2
    lda     int_tmp2+1
    adc     int_ptr+1
    sta     int_tmp2+1
:   dex
    bne     :-
    lda     int_tmp2+1
    pha
    lda     int_tmp2
    pha
    rts

;===============================================================================
; div16 - 16x16 divide
;===============================================================================
div16:
    pla
    sta     int_tmp
    pla
    sta     int_tmp+1
    pla
    sta     int_ptr
    pla
    sta     int_ptr+1
    lda     int_tmp
    ora     int_tmp+1
    bne     :+
    lda     #0
    tay
    pha
    pha
    rts
:   lda     #0
    sta     int_tmp2
    sta     int_tmp2+1
    ldx     #16
:   asl     int_ptr
    rol     int_ptr+1
    rol     int_tmp2
    rol     int_tmp2+1
    lda     int_tmp2
    sec
    sbc     int_tmp
    tay
    lda     int_tmp2+1
    sbc     int_tmp+1
    bcc     :+
    sty     int_tmp2
    sta     int_tmp2+1
    inc     int_ptr
:   dex
    bne     :-
    lda     int_ptr+1
    pha
    lda     int_ptr
    pha
    lda     int_tmp2
    ldy     int_tmp2+1
    rts

;===============================================================================
; get_big - Fetch BIG parameter
;===============================================================================
get_big:
    ldy     #0
    lda     (IPC), y
    bpl     @small
    tax
    inc     IPC
    bne     :+
    inc     IPC+1
:   ldy     #0
    lda     (IPC), y
    asl     a
    tay
    txa
    rol     a
    tax
    inc     IPC
    bne     :+
    inc     IPC+1
:   rts
@small:
    asl     a
    tay
    ldx     #0
    inc     IPC
    bne     :+
    inc     IPC+1
:   rts

;===============================================================================
; CSP handler implementations
;===============================================================================

; CSP 0: IOC - I/O Control
csp_ioc:
    lda     #0
    pha
    pha
    rts

; CSP 1: NEW - Allocate (push NIL)
csp_new:
    lda     #0
    pha
    pha
    rts

; CSP 4: EXIT - Exit procedure (warm restart)
csp_exit:
    ldx     #$FF
    txs
    jmp     COLD_START

; CSP 5: UREAD - Unit Read
; Params (TOS first): mode(W), count(W), block(W), buf(W), unit(W)
csp_uread:
    pla
    sta     int_ptr     ; mode low
    pla                 ; mode high
    pla
    sta     int_tmp2    ; count low
    pla                 ; count high
    pla                 ; block low
    pla                 ; block high
    pla
    sta     int_tmp     ; buffer low
    pla
    sta     int_tmp+1   ; buffer high
    pla
    sta     int_ptr2    ; unit low
    pla                 ; unit high (ignore)
    lda     int_ptr2
    cmp     #1
    beq     @con
    cmp     #2
    bne     @done
@con:
    ldy     #0
:   jsr     con_read
    sta     (int_tmp), y
    iny
    cpy     int_tmp2
    bne     :-
@done:
    lda     #0
    pha
    pha
    rts

; CSP 6: UWRITE - Unit Write
csp_uwrite:
    pla
    sta     int_ptr     ; mode low
    pla                 ; mode high
    pla
    sta     int_tmp2    ; count low
    pla                 ; count high
    pla                 ; block low
    pla                 ; block high
    pla
    sta     int_tmp     ; buffer low
    pla
    sta     int_tmp+1   ; buffer high
    pla
    sta     int_ptr2    ; unit low
    pla                 ; unit high
    lda     int_ptr2
    cmp     #1
    beq     @con
    cmp     #2
    bne     @done
@con:
    ldy     #0
:   lda     (int_tmp), y
    jsr     con_write
    iny
    cpy     int_tmp2
    bne     :-
@done:
    lda     #0
    pha
    pha
    rts

; CSP 9: TIM - Time (push 0)
csp_tim:
    lda     #0
    pha
    pha
    rts

; CSP 10: FLC - FillChar (stub)
csp_flc:
    lda     #0
    pha
    pha
    rts

; CSP 12: USTAT - Unit Status (push 0 = ready)
csp_ustat:
    lda     #0
    pha
    pha
    rts

; CSP 15: LDS - LoadSegment (stub, push -1)
csp_lds:
    lda     #$FF
    pha
    pha
    rts

; CSP 17: TNC - Truncate (stub, push 0)
csp_tnc:
    lda     #0
    pha
    pha
    rts

; CSP 18: RND - Round (stub, push 0)
csp_rnd:
    lda     #0
    pha
    pha
    rts

; CSP 26: MRK - Mark heap (push NP)
csp_mrk:
    lda     NP
    pha
    lda     NP+1
    pha
    rts

; CSP 27: RLS - Release heap (pop to NP)
csp_rls:
    pla
    sta     NP+1
    pla
    sta     NP
    rts

; CSP 28: IOR - I/O Result (push 0 = no error)
csp_ior:
    lda     #0
    pha
    pha
    rts

; CSP 29: UBUSY - Unit Busy (push 0 = not busy)
csp_ubusy:
    lda     #0
    pha
    pha
    rts

; CSP 31: UWAIT - Unit Wait
csp_uwait:
    lda     #0
    pha
    pha
    rts

; CSP 32: UCLR - Unit Clear
csp_uclr:
    lda     #0
    pha
    pha
    rts

; CSP 33: HLT - Halt
csp_hlt:
    jmp     csp_hlt

; CSP 34: MEMAV - Memory Available
csp_memav:
    sec
    lda     KP
    sbc     NP
    sta     int_tmp
    lda     KP+1
    sbc     NP+1
    pha
    lda     int_tmp
    pha
    rts

;===============================================================================
; Boot p-code program - echo loop
; Writes '!' to console, then reads/writes keys in a loop
;===============================================================================
boot_pcode:
    ; SLDC $21 '!' ; $70 addr   ; STO - store '!' at $0070
    .byte   $21, $70, $9A
    ; UNITWRITE(1, $70, 0, 1, 0) - write the '!'
    .byte   $00, $01, $00, $70, $01
    .byte   $9E, $06
    ; Loop: UNITREAD(1, $70, 0, 1, 0) - read a key
@loop:
    .byte   $00, $01, $00, $70, $01
    .byte   $9E, $05
    ; UNITWRITE(1, $70, 0, 1, 0) - echo the key
    .byte   $00, $01, $00, $70, $01
    .byte   $9E, $06
    ; UJP back to @loop
    ; 7 bytes UREAD + 7 bytes UWRITE + 1 byte UJP opcode = 15 from @loop
    ; Offset = -15 = $F1
    .byte   $B9, $F1

;===============================================================================
; scan_kbd_full - Full keyboard matrix scan
; Scans 8 columns x 8 rows via VIA PB0-2 (col) + PSG reg 14 (row)
; Returns: A = ASCII code, C=1 if key found, C=0 if no key
;===============================================================================
scan_kbd_full:
    ; Select PSG register 14 (I/O port A) for row drive writes
    jsr     ay_sel_reg14

    ;--- Check LSHIFT (col 4, row 4) ---
    lda     VIA_ORB
    and     #$F8
    ora     #4
    sta     VIA_ORB
    lda     #$EF
    jsr     ay_write_data
    nop
    nop
    lda     VIA_ORB
    and     #$08
    beq     @chk_rshift
    lda     #1
    sta     kbd_shift

@chk_rshift:
    ;--- Check RSHIFT (col 7, row 4) ---
    lda     VIA_ORB
    and     #$F8
    ora     #7
    sta     VIA_ORB
    lda     #$EF
    jsr     ay_write_data
    nop
    nop
    lda     VIA_ORB
    and     #$08
    beq     @scan_start
    lda     kbd_shift
    ora     #2
    sta     kbd_shift

@scan_start:
    lda     #0
    sta     kbd_col

@col_loop:
    ; Set column via PB0-2
    ldx     kbd_col
    lda     VIA_ORB
    and     #$F8
    stx     con_tmp
    ora     con_tmp
    sta     VIA_ORB

    lda     #0
    sta     kbd_row

@row_loop:
    ; Compute row mask = ~(1 << row), active low
    lda     #$01
    ldx     kbd_row
    beq     @got_mask
:   asl     a
    dex
    bne     :-
@got_mask:
    eor     #$FF
    jsr     ay_write_data
    nop
    nop

    ; Read PB3 (key sense)
    lda     VIA_ORB
    and     #$08
    bne     @key_found

@next_row:
    inc     kbd_row
    lda     kbd_row
    cmp     #8
    bne     @row_loop

    inc     kbd_col
    lda     kbd_col
    cmp     #8
    bne     @col_loop

    ; No key found
    lda     #0
    clc
    rts

@key_found:
    ; Calculate table index = col * 8 + row
    lda     kbd_col
    asl     a
    asl     a
    asl     a
    clc
    adc     kbd_row
    tax

    lda     kbd_shift
    beq     @unshifted
    lda     keytable_shifted, x
    bne     @return
@unshifted:
    lda     keytable, x
    beq     @next_row       ; Modifier key (value $00), skip
@return:
    sec
    rts

;===============================================================================
; ay_sel_reg14 - Select PSG I/O port A (reg 14) for writes
;===============================================================================
ay_sel_reg14:
    lda     #AY_PORT_A
    sta     VIA_ORA
    lda     #AY_PCR_SET_REG
    sta     VIA_PCR
    lda     #AY_PCR_INACTIVE
    sta     VIA_PCR
    rts

;===============================================================================
; ay_write_data - Write byte to the previously-selected PSG register
; Input: A = byte to write
;===============================================================================
ay_write_data:
    sta     VIA_ORA
    lda     #AY_PCR_WRITE_DATA
    sta     VIA_PCR
    lda     #AY_PCR_INACTIVE
    sta     VIA_PCR
    rts

;===============================================================================
; Keyboard lookup tables
; Organized column-major: keytable[col*8 + row]
; From Oric QWERTY keyboard matrix (oricutron qwktab)
; $00 = modifier key (Ctrl, Shift, Alt, cursor) - skip during scan
;===============================================================================
keytable:
    .byte   '7', 'n', '5', 'v', $00, '1', 'x', '3'      ; Col 0
    .byte   'j', 't', 'r', 'f', $00, $1B, 'q', 'd'      ; Col 1 (ESC = $1B)
    .byte   'm', '6', 'b', '4', $00, 'z', '2', 'c'      ; Col 2
    .byte   'k', '9', ';', '-', '#', $00, $5C, $27      ; Col 3 (\,')
    .byte   ' ', ',', '.', $00, $00, $00, $00, $00       ; Col 4 (SPACE, cursors, shift)
    .byte   'u', 'i', 'o', 'p', $00, $08, ']', '['      ; Col 5 (BS=$08)
    .byte   'y', 'h', 'g', 'e', $00, 'a', 's', 'w'      ; Col 6
    .byte   '8', 'l', '0', '/', $00, $0D, '`', '='      ; Col 7 (CR=$0D)

keytable_shifted:
    .byte   '&', 'N', '%', 'V', $00, '!', 'X', '#'      ; Col 0
    .byte   'J', 'T', 'R', 'F', $00, $1B, 'Q', 'D'      ; Col 1
    .byte   'M', '^', 'B', '$', $00, 'Z', '"', 'C'      ; Col 2 (" = $22)
    .byte   'K', '(', ':', '_', '~', $00, '|', '@'      ; Col 3
    .byte   ' ', '<', '>', $00, $00, $00, $00, $00       ; Col 4
    .byte   'U', 'I', 'O', 'P', $00, $08, '}', '{'      ; Col 5
    .byte   'Y', 'H', 'G', 'E', $00, 'A', 'S', 'W'      ; Col 6
    .byte   '*', 'L', ')', '?', $00, $0D, '~', '+'      ; Col 7
