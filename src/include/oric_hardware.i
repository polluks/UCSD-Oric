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
VIA_ORA_NH = $030F      ; Output Register A, no handshake (PSG data bus)

; VIA Port B bit masks
VIA_PB0 = $01           ; Keyboard row select bit 0
VIA_PB1 = $02           ; Keyboard row select bit 1
VIA_PB2 = $04           ; Keyboard row select bit 2
VIA_PB3 = $08           ; Keyboard sense line (1 = key pressed)
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
AY_PORT_A     = 14     ; I/O port A (keyboard column mask)
AY_PORT_B     = 15

; VIA PCR control values for AY-3-8912 register access
; CA2=BC1, CB2=BDIR
; PCR bits 1-3 = CA2, bits 5-7 = CB2
AY_PCR_INACTIVE   = $CC    ; CA2=0, CB2=0
AY_PCR_SET_REG    = $EE    ; CA2=1, CB2=1 (write register number)
AY_PCR_WRITE_DATA = $EC    ; CA2=0, CB2=1 (write data to register)
AY_PCR_READ_DATA  = $CE    ; CA2=1, CB2=0 (read data from register)
; PCR bits 0 and 4 (CA1/CB1 active edge) are not part of the PSG protocol and
; must be preserved, as the Atmos ROM does: pcr = (pcr AND AY_PCR_KEEP) OR value
AY_PCR_KEEP       = $11

;===============================================================================
; Microdisc FDC WD1793 at $0310
; (register order taken from the Microdisc ROM symbols: md_FDC_COMMAND=$0310,
;  md_FDC_TRACK=$0311, md_FDC_SECTOR=$0312, md_FDC_DATA=$0313)
;===============================================================================
FDC       = $0310       ; same as FDC_CMD, kept for old code
FDC_CMD   = $0310       ; Write: command   Read: status
FDC_STAT  = $0310       ; Read: status (alias of FDC_CMD)
FDC_TRK   = $0311       ; Track register (writing it does NOT seek)
FDC_SEC   = $0312       ; Sector register
FDC_DATA  = $0313       ; Data register
FDC_CTRL  = $0314       ; Control register
FDC_DRQ   = $0318       ; DRQ status: bit 7 = 0 -> byte available

; FDC commands (WD1793)
FDC_CMD_RESTORE  = $03      ; Restore (seek track 0)
FDC_CMD_SEEK     = $1F      ; Seek to track in the data register (verify, slowest step)
FDC_CMD_STEPIN   = $40      ; Step in
FDC_CMD_STEPOUT  = $60      ; Step out
FDC_CMD_READSEC  = $80      ; Read one sector
FDC_CMD_READMULT = $90      ; Read multiple sectors
FDC_CMD_WRITESEC = $A0      ; Write one sector
FDC_CMD_READADDR = $C0      ; Read address
FDC_CMD_FORCEINT = $D0      ; Force interrupt
FDC_CMD_READTRK  = $E0      ; Read track

; FDC status register bits (read from FDC_STAT)
FDC_ST_BUSY      = $01      ; command in progress
FDC_ST_LOSTDATA  = $04      ; type II/III: lost data (type I: track 0)
FDC_ST_CRC       = $08      ; CRC error
FDC_ST_RNF       = $10      ; record not found (type I: seek error)
FDC_ST_ERRMASK   = $1C      ; lost data | CRC | record not found / seek error

; FDC control register bits ($0314)
;   bit 0    IRQ enable
;   bit 1    1 = BASIC ROM visible, 0 = overlay RAM at $C000
;   bit 2    1 = MFM / double density, 0 = FM / single density
;   bit 4    side select
;   bits 5-6 drive select
;   bit 7    1 = Microdisc ROM disabled at $E000
FDC_CTRL_MFM    = $04       ; double density (MFM)
FDC_CTRL_ROMEN  = $02       ; BASIC ROM visible at $C000 (overlay off)
FDC_CTRL_ROMDIS = $80       ; Microdisc ROM disabled at $E000
FDC_CTRL_READY  = FDC_CTRL_MFM | FDC_CTRL_ROMDIS   ; $84, as used by the ROM
FDC_INTRQEN     = $01       ; Enable FDC interrupt to CPU
FDC_DRVSEL0     = $00       ; Drive select 0
FDC_SDSEL       = $00       ; single density (bit2 = 0)

;===============================================================================
; ULA Display
;===============================================================================
TEXT_SCREEN = $BB80     ; Text screen base (40 x 28 chars = 1120 bytes)
HIRES_SCREEN = $A000    ; HIRES bitmap (200 lines x 40 bytes)
STD_CHARSET = $9800     ; HIRES mode only: standard character set (128 chars x 8 bytes)
ALT_CHARSET = $9C00     ; HIRES mode only: alternate character set
TXT_STD_CHARSET = $B400 ; TEXT mode: standard character set
TXT_ALT_CHARSET = $B800 ; TEXT mode: alternate character set

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
; $A000-$BFDF is video memory (HIRES bitmap / text screen), so user RAM, the
; p-machine stack and SYSCOM must stay below the HIRES character sets at $9800.
RAM_TOP      = $96FF     ; Initial KP (stack grows down), just below SYSCOM
BIOS_BASE    = $C000     ; SYSTEM.ORIC BIOS starts here
INTERP_BASE  = $D000     ; p-code interpreter starts here
SYSCOM_BASE  = $9700     ; System communication area ($9700-$97FF)

; SYSCOM variables (at $9700)
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
