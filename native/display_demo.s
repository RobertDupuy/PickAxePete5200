; Display-only stress driver; same renderer, same audio IRQ as the game.
.export demo_tick
.segment "BSS"
demo_started:.res 1
demo_xdir:.res 5
demo_ydir:.res 5
.segment "CODE"
demo_tick:
 lda demo_started
 bne @tick
 inc demo_started
 ldx #4
@init:
 lda demo_start_x,x
 sta _rock_x,x
 lda demo_start_y,x
 sta _rock_y,x
 lda #1
 sta demo_xdir,x
 sta demo_ydir,x
 dex
 bpl @init
 lda #1
 sta _mode
 sta _scene_changed
 lda #0
 sta _pick_life
 sta _has_key
 lda #2
 sta _item_kind
 lda #4
 sta _item_shape
 ldx #7
 lda #255
@mask:sta _item_mask,x
 dex
 bpl @mask
@tick:
 inc _frame
 ldx #4
@rock:
 lda _rock_x,x
 clc
 adc demo_xdir,x
 sta _rock_x,x
 cmp #138
 bcc :+
 lda #255
 sta demo_xdir,x
: lda _rock_x,x
 cmp #12
 bcs :+
 lda #1
 sta demo_xdir,x
: lda _rock_y,x
 clc
 adc demo_ydir,x
 sta _rock_y,x
 cmp #184
 bcc :+
 lda #255
 sta demo_ydir,x
: lda _rock_y,x
 cmp #30
 bcs :+
 lda #1
 sta demo_ydir,x
: dex
 bpl @rock
 lda _rock_x
 sta _pete_x
 lda _rock_y
 sta _pete_y
 lda _frame
 and #3
 clc
 adc #18
 sta _pete_shape
 lda _rock_x+1
 sta _ladder_x
 lda _rock_y+1
 sta _ladder_y
 lda _frame
 and #3
 sta _ladder_shape
 lda _rock_x+2
 sta _item_x
 lda _rock_y+2
 sta _item_y
 lda _rock_x+3
 sta _effect_x
 lda _rock_y+3
 sta _effect_y
 lda _frame
 and #1
 sta _effect_shape
 lda _frame
 and #32
 beq :+
 lda #1
: sta _effect_size
 lda _frame
 lsr a
 lsr a
 lsr a
 and #7
 sta _effect_color
 sta _mine_color
 sta _door_color
 eor #3
 sta _door_color+1
 eor #5
 sta _door_color+2
 lda _frame
 and #31
 bne :+
 lda #$6a
 sta _sound_event
: rts
.segment "RODATA"
demo_start_x:.byte 20,43,67,89,112
demo_start_y:.byte 38,62,86,110,134
.segment "CODE"
