; p-code Opcode and CSP Constants
; Based on Apple II UCSD Pascal 1.3 p-machine
; Using .define (preprocessor macros) to avoid symbol conflicts with labels

;===============================================================================
; p-code Opcodes
;===============================================================================

; Short load constant (0-127) - opcode IS the value
; (opcodes $00-$7F are SLDC 0 through SLDC 127)

; Standard opcodes ($80-$FF)
.define P_ABI   $80    ; Absolute value integer
.define P_ABR   $81    ; Absolute value real
.define P_ADI   $82    ; Add integers
.define P_ADR   $83    ; Add reals
.define P_LAND  $84    ; Logical AND
.define P_DIF   $85    ; Set difference
.define P_DVI   $86    ; Divide integers
.define P_DVR   $87    ; Divide reals
.define P_CHK   $88    ; Check subrange
.define P_FLO   $89    ; Float next-to-top
.define P_FLT   $8A    ; Float top-of-stack
.define P_INN   $8B    ; Set membership
.define P_INT   $8C    ; Set intersection
.define P_LOR   $8D    ; Logical OR
.define P_MODI  $8E    ; Modulo integers
.define P_MPI   $8F    ; Multiply integers
.define P_MPR   $90    ; Multiply reals
.define P_NGI   $91    ; Negate integer
.define P_NGR   $92    ; Negate real
.define P_LNOT  $93    ; Logical NOT
.define P_SRS   $94    ; Subrange set
.define P_SBI   $95    ; Subtract integers
.define P_SBR   $96    ; Subtract reals
.define P_SGS   $97    ; Singleton set
.define P_SQI   $98    ; Square integer
.define P_SQR   $99    ; Square real
.define P_STO   $9A    ; Store indirect word
.define P_IXS   $9B    ; Index string
.define P_UNI   $9C    ; Set union
.define P_LDE   $9D    ; Load extended word
.define P_CSP   $9E    ; Call Standard Procedure
.define P_LDCN  $9F    ; Load constant NIL
.define P_ADJ   $A0    ; Adjust set
.define P_FJP   $A1    ; False jump
.define P_INC   $A2    ; Increment field pointer
.define P_IND   $A3    ; Static index load
.define P_IXA   $A4    ; Index array
.define P_LAO   $A5    ; Load global address
.define P_LSA   $A6    ; Load string address
.define P_LAE   $A7    ; Load extended address
.define P_MOV   $A8    ; Move words
.define P_LDO   $A9    ; Load global word
.define P_SAS   $AA    ; String assign
.define P_SRO   $AB    ; Store global word
.define P_XJP   $AC    ; Case jump
.define P_RNP   $AD    ; Return non-base procedure
.define P_CIP   $AE    ; Call intermediate procedure
.define P_EQU   $AF    ; Compare equal
.define P_GEQ   $B0    ; Compare greater-or-equal
.define P_GRT   $B1    ; Compare greater
.define P_LDA   $B2    ; Load intermediate address
.define P_LDC   $B3    ; Load multi-word constant
.define P_LEQ   $B4    ; Compare less-or-equal
.define P_LES   $B5    ; Compare less
.define P_LOD   $B6    ; Load intermediate word
.define P_NEQ   $B7    ; Compare not-equal
.define P_STR   $B8    ; Store intermediate word
.define P_UJP   $B9    ; Unconditional jump
.define P_LDP   $BA    ; Load packed field
.define P_STP   $BB    ; Store packed field
.define P_LDM   $BC    ; Load multiple words
.define P_STM   $BD    ; Store multiple words
.define P_LDB   $BE    ; Load byte
.define P_STB   $BF    ; Store byte
.define P_IXP   $C0    ; Index packed array
.define P_RBP   $C1    ; Return base procedure
.define P_CBP   $C2    ; Call base procedure
.define P_EQUI  $C3    ; Integer equality
.define P_GEQI  $C4    ; Integer greater-or-equal
.define P_GTRI  $C5    ; Integer greater
.define P_LLA   $C6    ; Load local address (alternate)
.define P_LDCI  $C7    ; Load integer constant
.define P_LEQI  $C8    ; Integer less-or-equal
.define P_LESI  $C9    ; Integer less
.define P_LDL   $CA    ; Load local word
.define P_NEQI  $CB    ; Integer not-equal
.define P_STL   $CC    ; Store local word
.define P_CXP   $CD    ; Call external procedure
.define P_CLP   $CE    ; Call local procedure
.define P_CGP   $CF    ; Call global procedure
.define P_LPA   $D0    ; Load packed array
.define P_STE   $D1    ; Store (alternate)
.define P_NOP   $D2    ; No operation
.define P_EFJ   $D3    ; Equal false jump
.define P_NFJ   $D4    ; Not-equal false jump
.define P_BPT   $D5    ; Breakpoint
.define P_XIT   $D6    ; Exit / cold boot
.define P_NOP2  $D7    ; No operation

; Short load local ($D8-$E7) - SLDL 1..16
; Short load global ($E8-$F7) - SLDO 1..16
; Indirect loads ($F8-$FF)
.define P_SIND0  $F8
.define P_SIND1  $F9
.define P_SIND2  $FA
.define P_SIND3  $FB
.define P_SIND4  $FC
.define P_SIND5  $FD
.define P_SIND6  $FE
.define P_SIND7  $FF

;===============================================================================
; CSP (Call Standard Procedure) function codes
;===============================================================================
.define CSP_IOC     0   ; I/O control
.define CSP_NEW     1   ; NEW variable allocation
.define CSP_MVL     2   ; MoveLeft (string)
.define CSP_MVR     3   ; MoveRight (string)
.define CSP_EXIT    4   ; Exit from procedure
.define CSP_UREAD   5   ; UnitRead
.define CSP_UWRITE  6   ; UnitWrite
.define CSP_IDS     7   ; IDsearch
.define CSP_TRS     8   ; TreeSearch
.define CSP_TIM     9   ; Time (get time/date)
.define CSP_FLC    10   ; FillChar
.define CSP_SCN    11   ; Scan
.define CSP_USTAT  12   ; UnitStatus
.define CSP_LDS    15   ; LoadSegment
.define CSP_ULS    16   ; UnitLineStatus
.define CSP_TNC    17   ; Truncate
.define CSP_RND    18   ; Round
.define CSP_SIN    19   ; Sine
.define CSP_COS    20   ; Cosine
.define CSP_LOG    21   ; Natural logarithm
.define CSP_ATAN   22   ; Arctangent
.define CSP_LN     23   ; Natural log (alternate)
.define CSP_EXP    24   ; Exponential
.define CSP_SQRT   25   ; Square root
.define CSP_MRK    26   ; Mark heap
.define CSP_RLS    27   ; Release heap
.define CSP_IOR    28   ; I/O result
.define CSP_UBUSY  29   ; Unit busy
.define CSP_POT    30   ; Power of ten
.define CSP_UWAIT  31   ; Unit wait
.define CSP_UCLR   32   ; Unit clear
.define CSP_HLT    33   ; Halt
.define CSP_MEMAV  34   ; Memory available

;===============================================================================
; Unit numbers (for CSP I/O calls)
;===============================================================================
.define UNIT_CONSOLE 1  ; Console (keyboard/screen)
.define UNIT_SYSTERM 2  ; System terminal
.define UNIT_GRAPHIC 3  ; Graphics screen
.define UNIT_PRINTER 4  ; Printer
.define UNIT_REMIN   5  ; Remote input
.define UNIT_REMOUT  6  ; Remote output
.define UNIT_DISK1   9  ; Disk drive 1 (APPLE0:)
