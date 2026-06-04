; Oric-1 / Atmos Hardware Constants
; ca65 syntax - for use with the UCSD p-System port

;===============================================================================
; VIA 6522 at $0300
;===============================================================================
VIA     = $0300         ; VIA base address
VIA_ORB = $0300         ; Output Register B (PB0-7)
VIA_IRA = $0301         ; Input Register A (same as ORA with handshake)
VIA_ORA = $0301         ; Output Register A
VIA_DDRB = $0302        ; Data Direction Register B
VIA_DDRA = $0303        ; Data Direction Register A
VIA_T1CL = $0304        ; Timer 1 Counter Low
VIA_T1CH = $0305        ; Timer 1 Counter High
VIA_T1LL = $0306        ; Timer 1 Latch Low
VIA_T1LH = $0307        ; Timer 1 Latch High
VIA_T2CL = $0308        ; Timer 2 Counter Low
VIA_T2CH = $0309        ; Timer 2 Counter High
VIA_SR  = $030A         ; Shift Register
VIA_ACR = $030B         ; Auxiliary Control Register
VIA_PCR = $030C         ; Peripheral Control Register
VIA_IFR = $030D         ; Interrupt Flag Register
VIA_IER = $030E         ; Interrupt Enable Register

; VIA Port B bit masks
VIA_PB0 = $01           ; Keyboard column select bit 0
VIA_PB1 = $02           ; Keyboard column select bit 1
VIA_PB2 = $04           ; Keyboard column select bit 2
VIA_PB3 = $08           ; Keyboard row sense (1 = key pressed)
VIA_PB4 = $10           ; Printer STROBE (active low pulse)
VIA_PB6 = $40           ; Tape motor control
VIA_PB7 = $80           ; Tape data output

;===============================================================================
; PSG AY-3-8912 (accessed via VIA)
;===============================================================================
; AY-3-8912 register numbers
AY_CHA_PER_L  = 0
AY_CHA_PER_H  = 1
AY_CHB_PER_L  = 2
AY_CHB_PER_H  = 3
AY_CHC_PER_L  = 4
AY_CHC_PER_H  = 5
AY_NOISE_PER  = 6
AY_STATUS     = 7
AY_CHA_AMP    = 8
AY_CHB_AMP    = 9
AY_CHC_AMP    = 10
AY_ENV_PER_L  = 11
AY_ENV_PER_H  = 12
AY_ENV_CYCLE  = 13
AY_PORT_A     = 14     ; I/O port A (keyboard row drive)
AY_PORT_B     = 15

; VIA PCR control values for AY-3-8912 register access
; CA2=BC1, CB2=BDIR
; PCR bits 1-3 = CA2, bits 5-7 = CB2
AY_PCR_INACTIVE   = $CC    ; CA2=0, CB2=0
AY_PCR_SET_REG    = $EE    ; CA2=1, CB2=1 (write register number)
AY_PCR_WRITE_DATA = $EC    ; CA2=0, CB2=1 (write data to register)
AY_PCR_READ_DATA  = $CE    ; CA2=1, CB2=0 (read data from register)

;===============================================================================
; Microdisc FDC WD1793 at $0310
;===============================================================================
FDC      = $0310
FDC_DATA  = $0310       ; Data register
FDC_STAT  = $0311       ; Status (read) / Command (write)
FDC_TRK   = $0312       ; Track register
FDC_SEC   = $0313       ; Sector register
FDC_CTRL  = $0314       ; Control register
FDC_DRQ   = $0318       ; DRQ status (bit 7 = 0 when ready)

; FDC command bits (WD1793)
FDC_CMD_RESTORE  = $03      ; Restore (seek track 0)
FDC_CMD_SEEK     = $1F      ; Seek to track
FDC_CMD_STEP     = $2B      ; Step in
FDC_CMD_STEPOUT  = $4B      ; Step out
FDC_CMD_READSEC  = $80      ; Read sector
FDC_CMD_WRITESEC = $A0      ; Write sector
FDC_CMD_READADDR = $C0      ; Read address
FDC_CMD_READTRK  = $E0      ; Read track
FDC_CMD_FORCEINT = $D0      ; Force interrupt

; FDC control register bits
FDC_ROMDIS  = $04           ; Disable ROM (bit1=0), MFM (bit3=0), clk divisor (bit2=1)
FDC_INTRQEN = $01           ; Enable FDC interrupt to CPU
FDC_DRVSEL0 = $00           ; Drive select 0
FDC_SDSEL   = $08           ; Single density select

;===============================================================================
; ULA Display
;===============================================================================
TEXT_SCREEN = $BB80     ; Text screen base (40 x 28 chars = 1120 bytes)
HIRES_SCREEN = $A000    ; HIRES bitmap (200 lines x 40 bytes)
STD_CHARSET = $9800     ; Standard character set (128 chars x 8 bytes)
ALT_CHARSET = $9C00     ; Alternate character set

; ULA inline attribute registers
ATTR_INK   = $00       ; Foreground color (bits 2-0: 0-7)
ATTR_STYLE = $08       ; Style register
ATTR_PAPER = $10       ; Background color (bits 2-0: 0-7)
ATTR_MODE  = $18       ; Video mode register

; Colors
COLOR_BLACK    = 0
COLOR_RED      = 1
COLOR_GREEN    = 2
COLOR_YELLOW   = 3
COLOR_BLUE     = 4
COLOR_MAGENTA  = 5
COLOR_CYAN     = 6
COLOR_WHITE    = 7

; Style bits
STYLE_ALTCHARSET = 1
STYLE_DBLHEIGHT  = 2
STYLE_BLINK      = 4

; Video mode register values
MODE_40X28_TEXT = $00
MODE_HIRES      = $01

;===============================================================================
; Memory Map
;===============================================================================
ZP_START     = $00
STACK_6502   = $0100     ; 6502 hardware stack (p-machine eval stack)
CSP_RET      = $0A       ; 2 bytes - csp_return save for CSP handlers
DSK_BUF      = $0C       ; 2 bytes - disk buffer pointer
CUR_TRK      = $0E       ; 1 byte - FDC current track cache
VIA_AREA     = $0300     ; VIA + FDC I/O page
HEAP_START   = $0500     ; Heap start (NP initial value)
STD_CHARSET_ADDR = $9800
ALT_CHARSET_ADDR = $9C00
HIRES_BASE   = $A000
TEXT_BASE    = $BB80
RAM_TOP      = $BFFF     ; Top of available user RAM
BIOS_BASE    = $C000     ; SYSTEM.ORIC BIOS starts here
INTERP_BASE  = $D000     ; p-code interpreter starts here
SYSCOM_BASE  = $BF00     ; System communication area

; SYSCOM variables (at $BF00)
IORSLT = SYSCOM_BASE + 0
XEQERR = SYSCOM_BASE + 2
SYSUNIT = SYSCOM_BASE + 4
GDIRP = SYSCOM_BASE + 8
BOMBP = SYSCOM_BASE + 10
STKBASE = SYSCOM_BASE + 12
LASTMP = SYSCOM_BASE + 14
BOMBPN = SYSCOM_BASE + 16
BOMBSN = SYSCOM_BASE + 18
ENDSTK = SYSCOM_BASE + 20
BOMBIPC = SYSCOM_BASE + 22
EOF_CH = SYSCOM_BASE + 80
SEG_TABLE = SYSCOM_BASE + 126

;===============================================================================
; P-machine Zero Page Registers (same as Apple II layout)
;===============================================================================
BASE   = $50            ; Base register (level 0 activation record)
MP     = $52            ; Markstack Pointer
JTAB   = $54            ; Jump Table pointer
SEG    = $56            ; Segment pointer
IPC    = $58            ; Interpreter Program Counter
NP     = $5A            ; New Pointer (heap top, grows up)
KP     = $5C            ; Program Stack Pointer (grows down)
STRP   = $5E            ; String Pointer
CODEP  = $60            ; Code pointer
CODELOW = $62           ; Lowest permissible value for CODEP

; Execution error codes
ERR_RANGE     = 1
ERR_NOPROC    = 2
ERR_UNCALL    = 3
ERR_STKOVFL   = 4
ERR_INTOVFL   = 5
ERR_DIV0      = 6
ERR_USERINT   = 8
ERR_SYSIO     = 9
ERR_IO        = 10
ERR_UNIMPL    = 11
ERR_FLOAT     = 12
ERR_STRGOVF   = 13
ERR_CODEOVF   = 16
