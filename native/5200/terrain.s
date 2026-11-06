; Native 6502 implementation of the hardware-independent terrain query.
; Equivalent C is retained in game.c for reference/oracle testing.
.export _terrain_query
.importzp _query_x, _query_y, _move_x, _move_y
.importzp _contact_flags, _correction_x, _correction_y
.import _floors
.import terrain_column, terrain_gap, terrain_level, terrain_distance
column=$50
distance=$51
level=$52
edge=$53
mask=$54
.segment "CODE"
_terrain_query:
 lda #0
 sta _contact_flags
 sta _correction_y
 sta edge
 lda _query_x
 clc
 adc _move_x
 tax
 cmp #9
 bcc @wall
 cmp #146
 bcc :+
@wall:
 lda #1
 sta _contact_flags
: lda terrain_column,x
 sta column
 lda terrain_gap,x
 sta _correction_x
 lda _query_y
 clc
 adc _move_y
 tax
 lda terrain_level,x
 cmp #8
 bne :+
 lda _contact_flags
 ora #2
 sta _contact_flags
 rts
: sta level
 lda terrain_distance,x
 sta distance
 ldx _move_y
 bmi @ceiling
 cmp #3
 bcs @ceiling
 sec
 sbc #3
 jmp @vertical
@ceiling:
 dec level
 lda distance
 cmp #15
 bcs :+
 rts
: sec
 sbc #15
 sta edge
 ldx _move_y
 bmi @vertical
 eor #$ff
 clc
 adc #1
@vertical:
 ldx _move_y
 bne :+
 lda #0
 beq :++
: clc
 adc _move_y
: sta _correction_y
 lda _contact_flags
 ora #2
 sta _contact_flags
 ldy level
 lda masks,y
 sta mask
 ldy column
 lda _floors,y
 and mask
 bne @supported
 lda _correction_x
 cmp #10
 bcc @gap
 cpy #0
 beq @gap
 dey
 lda _floors,y
 and mask
 bne @supported
@gap:
 lda _contact_flags
 ora #128
 sta _contact_flags
 rts
@supported:
 lda edge
 beq @done
 lda _correction_x
 cmp #10
 bcc @done
 sec
 sbc #16
 ldx _move_x
 bpl :+
 eor #$ff
 clc
 adc #1
: clc
 adc _move_x
 sta _correction_x
 lda _contact_flags
 ora #16
 sta _contact_flags
@done:rts
.segment "RODATA"
masks:.byte 1,2,4,8,16,32,64,128
