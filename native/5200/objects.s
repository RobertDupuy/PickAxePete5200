; Native game-space contact scan, independent of graphics or GTIA registers.
.export _rock_objects
.importzp _query_x, _query_y, _move_x, _move_y, _rock, _hit, _contact_flags
.import _rock_x, _rock_y, _rock_fall, _door_y, _door_open, _door_clock
.import _effect_start, _sound_queue
.export _rock_step
.import _rock_cursor, _rock_x_energy, _rock_y_energy, _rock_decay
.import _terrain_query
.importzp _correction_x, _correction_y
target_x=$55
target_y=$56
.segment "CODE"
_rock_objects:
 lda #0
 sta _hit
 lda _query_x
 clc
 adc _move_x
 sta target_x
 lda _query_y
 clc
 adc _move_y
 sta target_y
 ldx #0
@rock:
 cpx _rock
 beq @next
 lda _rock_y,x
 cmp #248
 beq @next
 lda target_x
 sec
 sbc _rock_x,x
 clc
 adc #7
 cmp #15
 bcs @next
 lda target_y
 sec
 sbc _rock_y,x
 clc
 adc #11
 cmp #23
 bcs @next
 lda #1
 sta _rock_fall,x
 jsr _effect_start
 jmp @hit
@next:
 inx
 cpx #5
 bne @rock
 lda target_x
 sec
 sbc #77
 clc
 adc #7
 cmp #15
 bcs @done
 ldx #0
@door:
 lda target_y
 sec
 sbc _door_y,x
 clc
 adc #11
 cmp #23
 bcc @door_hit
 inx
 cpx #3
 bne @door
@done:rts
@door_hit:
 lda #1
 sta _door_open,x
 lda #192
 sta _door_clock,x
@hit:
 lda #1
 sta _hit
 ldx _rock
 lda #248
 sta _rock_x,x
 sta _rock_y,x
 lda #0
 sta _move_x
 sta _move_y
 sta _contact_flags
 rts

; Two scheduled calls per frame. The five rocks keep the original round-robin
; cadence. Energy bytes are game data (direction, acceleration and decay).
_rock_step:
 inc _rock_cursor
 lda _rock_cursor
 cmp #5
 bcc :+
 lda #0
 sta _rock_cursor
: sta _rock
 tax
 lda _rock_y,x
 cmp #248
 bne :+
 rts
: sta _query_y
 lda _rock_x,x
 sta _query_x
 lda _rock_fall,x
 beq @ordinary
 lda #4
 sta _sound_queue
 lda #0
 sta _move_x
 lda #2
 sta _move_y
 jsr _rock_objects
 lda _hit
 bne @return
 ldx _rock
 lda _rock_y,x
 clc
 adc #2
 sta _rock_y,x
 cmp #182
 bcc @return
 sta _query_y
 jsr _effect_start
 ldx _rock
 lda #248
 sta _rock_x,x
 sta _rock_y,x
@return:rts
@ordinary:
 lda _rock_x_energy,x
 jsr energy_velocity
 sta _move_x
 lda _rock_y_energy,x
 jsr energy_velocity
 sta _move_y
 jsr _terrain_query
 lda _contact_flags
 and #17
 beq :+
 lda _correction_x
 sta _move_x
: lda _contact_flags
 bmi :+
 and #2
 beq :+
 lda _correction_y
 sta _move_y
: jsr _rock_objects
 lda _hit
 bne @return
 ldx _rock
 lda _rock_x,x
 clc
 adc _move_x
 sta _rock_x,x
 lda _rock_y,x
 clc
 adc _move_y
 sta _rock_y,x
 lda _contact_flags
 and #17
 beq @vertical
 lda _rock_x_energy,x
 and #254
 beq :+
 lda _rock_x_energy,x
 sec
 sbc #2
 sta _rock_x_energy,x
: lda _rock_x_energy,x
 eor #1
 sta _rock_x_energy,x
 inc _sound_queue
@vertical:
 lda _contact_flags
 bpl @surface
 lda _rock_y_energy,x
 clc
 adc #2
 bcs @decay
 sta _rock_y_energy,x
 jmp @decay
@surface:
 and #16
 bne @decay
 lda _contact_flags
 and #2
 beq @decay
 lda _rock_y_energy,x
 and #254
 beq :+
 lda _rock_y_energy,x
 sec
 sbc #2
 inc _sound_queue
 eor #1
: sta _rock_y_energy,x
@decay:
 lda _rock_y_energy,x
 lsr a
 bcc @return2
 and #112
 bne @return2
 lda _rock_decay,x
 clc
 adc #2
 sta _rock_decay,x
 cmp _rock_y_energy,x
 bcc @return2
 lda #0
 sta _rock_decay,x
 lda _rock_y_energy,x
 and #254
 beq :+
 sec
 sbc #2
: sta _rock_y_energy,x
 lda _rock_x_energy,x
 and #254
 beq @return2
 lda _rock_x_energy,x
 sec
 sbc #2
 sta _rock_x_energy,x
@return2:rts

energy_velocity:
 sta target_x
 ldy #1
 cmp #128
 bcs @three
 cmp #64
 bcc @direction
 iny
 bne @direction
@three:ldy #3
@direction:
 lda target_x
 lsr a
 tya
 bcc :+
 eor #255
 clc
 adc #1
: rts
