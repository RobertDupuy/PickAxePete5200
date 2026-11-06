; Direct native rule routines. Equivalent C remains the ROM-checked model.
.export _item_step,_pick_rocks,_pete_contacts
.importzp _mode,_frame,_pete_x,_pete_y,_pick_life,_has_key,_jump_phase
.importzp _last_x,_last_y,_terrain,_evade_cooldown,_pete_hits_rock
.importzp _query_x,_query_y
.import _score_pending,_sound_event,_sound_queue,_item_mask
.import _item_kind,_item_x,_item_y,_item_age,_item_shape
.import _rock_x,_rock_y,_door_color,_door_open,_door_clock,_door_y
.import _effect_start,_clear_objects,_random_byte,_death_clock
.import _mine_color,_transition_clock
ct_distance=$59
.segment "CODE"
_item_step:
 lda #255
.repeat 8,K
 sta _item_mask+K
.endrepeat
 lda _pick_life
 beq @loose
 cmp #193
 bcs :+
 rts
: lda #$82
 sta _sound_queue
 lda _frame
 and #2
 beq :+
 rts
: jsr _random_byte
.repeat 5,K
 sta _item_mask+1+K
 .if K<4
 eor #255
 lsr a
 bcc :+
 ora #128
:
 .endif
.endrepeat
 rts
@loose:
 lda _item_kind
 bne :+
 rts
: cmp #2
 beq @up
 lda _item_y
 clc
 adc #2
 jmp @position
@up:
 lda _item_y
 sec
 sbc #2
@position:
 sta _item_y
 cmp #28
 bcc @top
 cmp #176
 bcs @bottom
 lda #$84
 sta _sound_queue
 lda _frame
 lsr a
 lsr a
 and #3
 ldx _item_kind
 cpx #2
 bne :+
 ora #4
: sta _item_shape
 rts
@top:
 lda #28
 bne @clamp
@bottom:
 lda #176
@clamp:
 sta _item_y
 inc _item_age
 inc _item_age
 bne @age
 lda #0
 sta _item_kind
 lda #248
 sta _item_x
 sta _item_y
 rts
@age:
 lda #0
 ldx _item_kind
 cpx #2
 bne :+
 lda #4
: sta _item_shape
 lda _item_age
 bmi :+
 rts
: lda #$82
 sta _sound_queue
 jsr _random_byte
.repeat 8,K
 eor #255
 lsr a
 bcc :+
 ora #128
: sta _item_mask+K
.endrepeat
 rts

_pick_rocks:
 lda _pick_life
 bne :+
 rts
: lda _item_x
 sta _query_x
 lda _item_y
 sta _query_y
@rocks:
 ldx #0
@one:
 lda _rock_y,x
 cmp #248
 beq @next
 lda _query_y
 sec
 sbc _rock_y,x
 clc
 adc #11
 cmp #23
 bcs @next
 lda _query_x
 sec
 sbc _rock_x,x
 clc
 adc #7
 cmp #15
 bcs @next
 lda _score_pending
 clc
 adc #3
 sta _score_pending
 txa
 pha
 jsr _effect_start
 pla
 tax
 lda #248
 sta _rock_x,x
 sta _rock_y,x
 rts
@next:
 inx
 cpx #5
 bne @one
 rts

_pete_contacts:
 lda _evade_cooldown
 beq :+
 dec _evade_cooldown
: lda _mode
 cmp #2
 bne :+
 rts
: ldx #0
@rock:
 lda _rock_y,x
 cmp #248
 beq @next
 lda _pete_y
 sec
 sbc _rock_y,x
 bcs :+
 eor #255
 clc
 adc #1
: sta ct_distance
 cmp #10
 bcs @next
 lda _pete_x
 sec
 sbc _rock_x,x
 clc
 adc #2
 cmp #5
 bcs @next
 lda _pete_hits_rock
 beq @evade
 lda _jump_phase
 beq @death
 lda ct_distance
 cmp #6
 bcs @evade
@death:
 lda #2
 sta _mode
 lda #1
 sta _death_clock
 rts
@evade:
 lda _jump_phase
 beq @return
 lda _evade_cooldown
 bne @return
 lda #9
 sta _evade_cooldown
 inc _score_pending
 lda #$56
 sta _sound_event
@return:rts
@next:
 inx
 cpx #5
 bne @rock
 lda _pete_x
 sec
 sbc #77
 clc
 adc #6
 cmp #13
 bcs @return
 ldx #0
@door:
 lda _pete_y
 sec
 sbc _door_y,x
 clc
 adc #5
 cmp #11
 bcc @enter
 inx
 cpx #3
 bne @door
 rts
@enter:
 lda _has_key
 beq @eject
 lda _door_color,x
 tay
 lda door_to_grid,y
 sta _mine_color
 lda _score_pending
 clc
 adc #20
 sta _score_pending
 jsr _clear_objects
 lda #3
 sta _mode
 lda #1
 sta _transition_clock
 lda #72
 sta _pete_x
 lda #104
 sta _pete_y
 lda #$a0
 sta _sound_queue
 rts
@eject:
 lda #1
 sta _door_open,x
 lda #192
 sta _door_clock,x
 jsr _random_byte
 and #1
 beq @go_left
 lda #1
 sta _last_x
 lda #$a5
 bne @escape
@go_left:
 lda #255
 sta _last_x
 lda #$ab
@escape:
 sta _sound_event
 lda #255
 sta _last_y
 inc _jump_phase
 rts
.segment "RODATA"
door_to_grid:.byte 0,4,2,6,1,5,3,7
