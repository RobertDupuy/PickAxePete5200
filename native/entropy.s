; Native implementation of the counter model in entropy.c. A holds the argument.
.export _entropy_value, _entropy_fraction, _entropy_frame, _entropy_advance
.export _entropy_write, _random_byte
.segment "BSS"
_entropy_value:.res 1
_entropy_fraction:.res 1
elapsed:.res 2
entropy_sum:.res 1
entropy_high:.res 1
fifths:.res 1
.segment "CODE"
_entropy_write:
 sta _entropy_value
 rts
_random_byte:
 lda _entropy_value
 pha
 inc elapsed
 bne :+
 inc elapsed+1
: inc _entropy_fraction
 lda _entropy_fraction
 cmp #32
 bne :+
 lda #0
 sta _entropy_fraction
 inc _entropy_value
: pla
 ldx #0
 rts
_entropy_advance:
 tax
 clc
 adc elapsed
 sta elapsed
 bcc :+
 inc elapsed+1
: txa
 clc
 adc _entropy_fraction
 sta entropy_sum
 lda #0
 rol a
 sta entropy_high
 lda entropy_sum
 lsr entropy_high
 ror a
 lsr a
 lsr a
 lsr a
 lsr a
 clc
 adc _entropy_value
 sta _entropy_value
 lda entropy_sum
 and #31
 sta _entropy_fraction
 rts
_entropy_frame:
 clc
 lda fifths
 adc #3
 cmp #5
 bcc :+
 sbc #5
 sta fifths
 lda #1
 bne :++
: sta fifths
 lda #0
: pha
 sec
 lda  #<$1755
 sbc elapsed
 sta entropy_sum
 lda  #>$1755
 sbc elapsed+1
 sta entropy_high
 pla
 clc
 adc entropy_sum
 sta entropy_sum
 bcc :+
 inc entropy_high
: clc
 lda entropy_sum
 adc _entropy_fraction
 sta entropy_sum
 bcc :+
 inc entropy_high
: lda entropy_high
 asl a
 asl a
 asl a
 sta entropy_high
 lda entropy_sum
 lsr a
 lsr a
 lsr a
 lsr a
 lsr a
 ora entropy_high
 clc
 adc _entropy_value
 sta _entropy_value
 lda entropy_sum
 and #31
 sta _entropy_fraction
 lda #0
 sta elapsed
 sta elapsed+1
 rts
