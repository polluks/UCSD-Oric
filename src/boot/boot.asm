.include "oric_hardware.i"
        .segment "LOADER"
        sei
        cld
        lda     #$07
        sta     $BB80
        lda     #$10
        sta     $BB81
        lda     #$20
        sta     $BB82
        ldx     #0
loop:
        lda     #'X'
        sta     $BD1A,x
        inx
        cpx     #10
        bne     loop
halt:
        jmp     halt
