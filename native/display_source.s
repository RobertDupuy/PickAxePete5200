; Input and original artwork selection fragments used by generate_fixed.py.
.setcpu "6502"
.import _game_init, _game_tick, zerobss
.importzp c_sp
.importzp _mode, _frame, _pete_x, _pete_y, _pete_shape, _pick_life, _has_key
.importzp _jump_phase, _last_x, _last_y, _terrain
.importzp _input_x, _input_y, _input_fire
.importzp _pete_hits_rock, _pete_hits_item, _pete_hits_ladder
.import _mine_number, _mine_color, _scene_changed, _floors, _score, _high_score
.import _name_chars, _name_changed, _score_changed, _input_mine, _input_name
.import _ladder_x, _ladder_y, _ladder_shape, _ladder_stage
.import _item_x, _item_y, _item_kind, _item_shape, _item_age
.import _effect_x, _effect_y, _effect_phase, _effect_clock
.import _rock_x, _rock_y, _rock_fall, _door_color, _door_open, _transition_clock
.import _effect_shape, _effect_color, _effect_size, _item_mask, _transition_stage
.import reverse_bits
.import _sound_event, sound_update, audio_init, audio_irq
.import pete_shapes, ladder_shapes, pick_shapes, loose_shapes, effect_shapes
.import letter_shapes, rgb_to_atari, grid_to_atari
.import screen_row_lo, screen_row_hi, background_row_lo, background_row_hi
.export start, frame_begin, frame_complete, nmi, vbi_begin, vbi_end
.export frame_number, missed_frames, queue_bytes, queue_overflow, pm_collision
.import prepare_hud,commit_hud,hud_scene
.import select_setup
.export pending
.export hud_shadow
.export render_begin, render_end, queue_start, scene_setup

; Interrupt scratch
read_input:
 lda #0
 sta _input_x
 sta _input_y
 sta _input_fire
 lda $d300
 lsr a
 bcs :+
 dec _input_y
: lsr a
 bcs :+
 inc _input_y
: lsr a
 bcs :+
 dec _input_x
: lsr a
 bcs :+
 inc _input_x
: lda $d010
 bne :+
 inc _input_fire
: lda $d20f
 and #4
 beq @key
 lda #$ff
 sta old_key
 rts
@key:
 lda $d209
 and #$3f
 cmp old_key
 beq @done
 sta old_key
 tax
 lda keymap,x
 cmp #10
 bcs @letter
 sta _input_mine
 rts
@letter:
 cmp #65
 bcs @done
 sta _input_name
@done:rts

make_display_list:
prepare_sprites:
 lda _pete_x
 sta pm_x
 lda _pete_y
 sta pm_y
 lda #$1c
 sta pm_color
 lda _has_key
 beq :+
 lda _frame
 and #4
 beq :+
 lda rgb_to_atari
 sta pm_color
: lda _pete_shape
 asl a
 asl a
 asl a
 sta src
 lda #0
 rol a
 clc
 adc #>pete_shapes
 sta src+1
 clc
 lda src
 adc #<pete_shapes
 sta src
 bcc :+
 inc src+1
: ldy #7
@pete:
 lda (src),y
 sta pm_pattern,y
 dey
 bpl @pete
 lda _ladder_x
 sta pm_x+1
 lda _ladder_y
 sta pm_y+1
 lda #$0e
 sta pm_color+1
 lda _ladder_shape
 asl a
 asl a
 asl a
 tax
 ldy #0
@ladder:
 lda ladder_shapes,x
 sta pm_pattern+8,y
 inx
 iny
 cpy #8
 bne @ladder
 lda #$68
 sta pm_color+2
 lda _pick_life
 beq @loose
 lda _item_x
 sta pm_x+2
 lda _item_y
 sta pm_y+2
 lda _item_shape
 asl a
 asl a
 asl a
 tax
 ldy #0
@pick:
 lda pick_shapes,x
 sta pm_pattern+16,y
 inx
 iny
 cpy #8
 bne @pick
 lda _pick_life
 cmp #193
 bcc @effect
 lda _frame
 and #8
 bne @effect
 lda #$0e
 sta pm_color+2
 jmp @effect
@loose:
 lda _item_kind
 bne :+
 lda #248
 sta pm_y+2
 jmp @effect
: lda _item_x
 sta pm_x+2
 lda _item_y
 sta pm_y+2
 lda _item_kind
 cmp #2
 bne :+
 lda #$1c
 sta pm_color+2
: lda _item_shape
 asl a
 asl a
 asl a
 tax
 ldy #0
@loose_bytes:
 lda loose_shapes,x
 sta pm_pattern+16,y
 inx
 iny
 cpy #8
 bne @loose_bytes
@effect:
 ; Masks are game data in source bit order; reverse into Atari MSB-left.
 ldy #7
@mask:
 ldx _item_mask,y
 lda reverse_bits,x
 and pm_pattern+16,y
 sta pm_pattern+16,y
 dey
 bpl @mask
 lda _effect_x
 sta pm_x+3
 lda _effect_y
 sta pm_y+3
 ldx _effect_color
 lda rgb_to_atari,x
 sta pm_color+3
 lda _effect_shape
 and #1
 asl a
 asl a
 asl a
 tax
 ldy #0
@effect_bytes:
 lda effect_shapes,x
 sta pm_pattern+24,y
 inx
 iny
 cpy #8
 bne @effect_bytes
@doors:
 ldx #2
@palette:
 lda _door_color,x
 tay
 lda rgb_to_atari,y
 sta live_door_colors,x
 dex
 bpl @palette
 rts

nmi:
keymap:
.byte $0e,$1e,$ff,$ff,$ff,$1f,$ff,$ff,$17,$ff,$0f,$15,$40,$16,$ff,$ff
.byte $24,$ff,$23,$ff,$ff,$25,$22,$21,$04,$ff,$03,$06,$ff,$05,$02,$01
.byte $ff,$0c,$ff,$2d,$ff,$26,$ff,$ff,$13,$ff,$12,$2c,$ff,$14,$11,$18
.byte $09,$ff,$00,$07,$ff,$08,$ff,$ff,$1b,$1d,$1a,$ff,$ff,$1c,$19,$20

.include "effects.s"
