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
.export start, frame_begin, frame_complete, nmi, vbi_begin, vbi_end
.export frame_number, missed_frames, queue_bytes, queue_overflow, pm_collision
.import prepare_hud,commit_hud,hud_scene
.import select_setup
.export pending
.export hud_shadow
.export render_begin, render_end, queue_start, scene_setup


src=$30
dst=$32
back=$34
shape=$38
row=$3a
column=$3b
object=$3c
temp=$3e
bits=$3f
draw_x=$40
draw_y=$41
glyph=$42
color=$43
frame_seen=$45
seed=$46
old_key=$48
SCREEN=$8000
FONT=$9000
WORKMAP=$a000
BACKMAP=$a800
STAGE=$b000
PMBASE=$c800
DLIST=$0400
queue_start=$b000
.segment "BSS"
frame_number:.res 2
missed_frames:.res 2
queue_bytes:.res 2
queue_overflow:.res 1
pending:.res 1
display_ready:.res 1
pm_collision:.res 3
pm_x:.res 4
pm_y:.res 4
pm_color:.res 4
pm_pattern:.res 32
pm_old_y:.res 4
pm_old_height:.res 4
pm_height:.res 4
pm_width:.res 4
pm_dirty:.res 4
last_pete_shape:.res 1
last_ladder_shape:.res 1
last_effect_shape:.res 1
pm_staged:.res 160
live_door_colors:.res 3
ready_door:.res 3
live_door:.res 3
hud_shadow:.res 14
active_rows:.res 25
work_count:.res 1
work_src_lo:.res 45
work_src_hi:.res 45
font_page:.res 1
live_font_page:.res 1
ready_door_colors:.res 3
ready_mine_color:.res 1
live_mine_color:.res 1
copy_slots:.res 1
copy_tail:.res 1
base_lo:.res 5
base_hi:.res 5
old_base_lo:.res 5
old_base_hi:.res 5
cell_count:.res 1
old_count:.res 1
cell_lo:.res 45
cell_hi:.res 45
cell_code:.res 45
old_lo:.res 45
old_hi:.res 45
rock_color:.res 1
live_rock_color:.res 1
transition_live:.res 1
.segment "STARTUP"
start:
 sei
 cld
 lda #0
 sta $d40e
 sta $d400
 sta $d20e
 sta $d01d
 sta $d208
 lda #$fe
 sta $d301
 ldx #0
@load:
 .repeat 8,P
 lda $8000+P*256,x
 sta $d800+P*256,x
 .endrepeat
 .repeat 29,P
 lda $a000+P*256,x
 sta $e000+P*256,x
 .endrepeat
 inx
 beq :+
 jmp @load
: ldx #$ff
 txs
 lda #0
 ldx #0
@zp:sta $00,x
 inx
 bne @zp
 lda #$10
 sta c_sp+1
 jsr zerobss
 lda #<nmi
 sta $fffa
 lda #>nmi
 sta $fffb
 lda #<audio_irq
 sta $fffe
 lda #>audio_irq
 sta $ffff
 lda #3
 sta $d20f
 lda #255
 sta old_key
 jsr audio_init
 jsr _game_init
 jsr scene_setup
 lda #$c0
 sta $d40e
 lda frame_number
 sta frame_seen
 cli
main_loop:
 lda pending
 bne main_loop
 lda frame_number
 cmp frame_seen
 beq main_loop
 sec
 sbc frame_seen
 cmp #1
 beq :+
 inc missed_frames
 bne :+
 inc missed_frames+1
: lda frame_number
 sta frame_seen
frame_begin:
 jsr read_input
 lda pm_collision
 sta _pete_hits_rock
 lda pm_collision+1
 sta _pete_hits_item
 lda pm_collision+2
 sta _pete_hits_ladder
 jsr _game_tick
 lda _mode
 bne :+
 jmp frame_complete
:
 lda _scene_changed
 beq :+
 jsr scene_setup
 lda frame_number
 sta frame_seen
: jsr prepare_sprites
 jsr pm_prepare
 jsr prepare_effects
render_begin:
 jsr prepare_hud
 jsr rocks_prepare
render_end:
 jsr sound_update
frame_complete:
 lda #1
 sta pending
 jmp main_loop
.segment "CODE"

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
 ldx #0
@copy:lda fixed_dlist,x
 sta DLIST,x
 inx
 cpx #fixed_dlist_end-fixed_dlist
 bne @copy
 lda #<DLIST
 sta $d402
 lda #>DLIST
 sta $d403
 lda #$c8
 sta $d407
 lda #3
 sta $d01d
 lda #2
 sta $d401
 lda #$11
 sta $d01b
 lda #56
 sta $d004
 lda #200
 sta $d005
 lda #0
 sta $d006
 sta $d007
 sta $d00c
 lda #0
 sta $d008
 sta $d009
 sta $d00a
 sta $d00b
 sta $d01a
 rts
scene_setup:
 lda _mode
 bne :+
 jmp select_setup
:
 lda #0
 sta display_ready
 sta pending
 sta $d400
 sta _scene_changed
 sta transition_live
 sta cell_count
 sta old_count
 ldx #0
@clear:
 .repeat 4,P
 sta SCREEN+P*256,x
 sta WORKMAP+P*256,x
 sta BACKMAP+P*256,x
 .endrepeat
 .repeat 8,P
 sta PMBASE+P*256,x
 .endrepeat
 .repeat 12,P
 lda static_font+P*256,x
 sta FONT+P*256,x
 .endrepeat
 lda #0
 inx
 beq :+
 jmp @clear
: lda #$0f
 ldx #40
@walls:
 sta PMBASE+$300,x
 inx
 cpx #235
 bne @walls
 lda #0
 ldx #3
@pm:sta pm_old_height,x
 sta $d000,x
 dex
 bpl @pm
 lda #255
 sta last_pete_shape
 sta last_ladder_shape
 sta last_effect_shape
 ldx #13
@hud:sta hud_shadow,x
 dex
 bpl @hud
 ; One static cell map; runtime floor removal uses current semantic floors.
 ldx #0
@base:
 .repeat 4,P
 lda base_map+P*256,x
 sta BACKMAP+P*256,x
 .endrepeat
 inx
 bne @base
 lda #0
 sta object
@col:
 ldx object
 lda _floors,x
 sta bits
 txa
 asl a
 asl a
 clc
 adc #2
 sta column
 lda #<BACKMAP
 sta dst
 lda #>BACKMAP
 sta dst+1
 lda #8
 sta row
@floor:
 lsr bits
 bcc @nextrow
 ldy column
 lda (dst),y
 ora #1
 sta (dst),y
 iny
 lda #1
 sta (dst),y
 iny
 sta (dst),y
 iny
 sta (dst),y
 iny
 lda (dst),y
 ora #2
 sta (dst),y
@nextrow:
 clc
 lda dst
 adc #120
 sta dst
 bcc :+
 inc dst+1
: dec row
 bne @floor
 inc object
 lda object
 cmp #9
 bne @col
 lda #0
 sta _score_changed
 sta _name_changed
 jsr make_display_list
 jsr prepare_sprites
 jsr pm_prepare
 jsr prepare_effects
 jsr rocks_prepare
 jsr rocks_commit
 jsr pm_commit
 ldx #0
@copy:
 .repeat 4,P
 lda BACKMAP+P*256,x
 sta SCREEN+P*256,x
 .endrepeat
 inx
 bne @copy
 jsr hud_scene
 lda #1
 sta _score_changed
 sta _name_changed
 jsr prepare_hud
 jsr commit_hud
 jsr commit_palette
 jsr frame_palette
 lda #0
 sta $d01e
 lda #1
 sta display_ready
 lda #$3e
 sta $d400
 rts

prepare_sprites:
 lda #0
 sta pm_dirty
 sta pm_dirty+1
 sta pm_dirty+3
 lda #1
 sta pm_dirty+2
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
 cmp last_pete_shape
 beq @pete_copied
 sta last_pete_shape
 inc pm_dirty
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
: .repeat 8,R
 ldy #R
 lda (src),y
 sta pm_pattern+R
 .endrepeat
@pete_copied:
 lda _ladder_x
 sta pm_x+1
 lda _ladder_y
 sta pm_y+1
 lda #$0e
 sta pm_color+1
 lda _ladder_shape
 cmp last_ladder_shape
 beq @ladder_copied
 sta last_ladder_shape
 inc pm_dirty+1
 asl a
 asl a
 asl a
 tax
 .repeat 8,R
 lda ladder_shapes+R,x
 sta pm_pattern+8+R
 .endrepeat
@ladder_copied:
 lda #$68
 sta pm_color+2
 lda _pick_life
 bne :+
 jmp @loose
:
 lda _item_x
 sta pm_x+2
 lda _item_y
 sta pm_y+2
 lda _item_shape
 asl a
 asl a
 asl a
 tax
 .repeat 8,R
 lda pick_shapes+R,x
 sta pm_pattern+16+R
 .endrepeat
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
 .repeat 8,R
 lda loose_shapes+R,x
 sta pm_pattern+16+R
 .endrepeat
@effect:
 ; Masks are game data in source bit order; reverse into Atari MSB-left.
 .repeat 8,R
 ldx _item_mask+R
 lda reverse_bits,x
 and pm_pattern+16+R
 sta pm_pattern+16+R
 .endrepeat
 lda _effect_x
 sta pm_x+3
 lda _effect_y
 sta pm_y+3
 ldx _effect_color
 lda rgb_to_atari,x
 sta pm_color+3
 lda _effect_shape
 and #1
 cmp last_effect_shape
 beq @doors
 sta last_effect_shape
 inc pm_dirty+3
 asl a
 asl a
 asl a
 tax
 .repeat 8,R
 lda effect_shapes+R,x
 sta pm_pattern+24+R
 .endrepeat
@doors:
 ldx #2
@palette:
 lda _door_color,x
 tay
 lda rgb_to_atari,y
 sta ready_door_colors,x
 dex
 bpl @palette
 rts


.include "fixed_renderer.s"
.include "display_demo.s"
nmi:
 pha
 bit $d40f
 bmi dli_dispatch
 sta $d40f
 lda _mode
 bne :+
 inc frame_number
 bne @select_ready
 inc frame_number+1
@select_ready:
 lda #0
 sta pending
:
 pla
 rti
; Palette DLIs only use A. Dispatch directly, before character DMA can delay
; WSYNC past the target scanline. The next handler is installed after the
; time-critical register writes; frame_palette starts the chain each frame.
dli_dispatch:
 jmp dli_middle
dli_middle:
 lda live_door_colors+1
 sta $d40a
 sta $d017
 lda #<dli_bottom
 sta dli_dispatch+1
 lda #>dli_bottom
 sta dli_dispatch+2
 pla
 rti
dli_bottom:
 lda live_door_colors
 sta $d40a
 sta $d017
 lda #<dli_hud
 sta dli_dispatch+1
 lda #>dli_hud
 sta dli_dispatch+2
 pla
 rti
dli_hud:
 lda #$e4
 sta $d40a
hud_font_switch:
 sta $d409
 lda #$1c
 sta $d017
 lda #$0e
 sta $d018
 ; The bottom floor is a bitmap and needs no font/palette switch. Keep the
 ; HUD font through both score rows and restore the mine font in blanking.
 lda #<vbi_begin
 sta dli_dispatch+1
 lda #>vbi_begin
 sta dli_dispatch+2
 pla
 rti
vbi_begin:
 ; Finish the last floor scanline before committing; permit the noise IRQ.
 sta $d40a
 txa
 pha
 tya
 pha
 tsx
 lda $0104,x
 and #4
 bne :+
 cli
: inc frame_number
 bne :+
 inc frame_number+1
: lda $d004
 and #4
 sta pm_collision
 lda $d00c
 and #4
 sta pm_collision+1
 lda $d00c
 and #2
 sta pm_collision+2
 lda display_ready
 beq vbi_end
 lda pending
 beq @palette
 lda _mode
 cmp #3
 bne :+
 jsr transition_commit
 jmp @sprites
: jsr rocks_commit
@sprites:
 jsr pm_commit
 jsr commit_hud
 jsr commit_palette
 lda #0
 sta pending
@palette:
 jsr frame_palette
 lda #0
 sta $d01e
vbi_end:
 jmp nmi_exit
commit_palette:
 lda font_page
 sta live_font_page
 lda rock_color
 sta live_rock_color
 ldx #2
@doors:
 lda ready_door_colors,x
 sta live_door_colors,x
 dex
 bpl @doors
 ldx _mine_color
 lda grid_to_atari,x
 sta live_mine_color
 rts
frame_palette:
 lda #<dli_middle
 sta dli_dispatch+1
 lda #>dli_middle
 sta dli_dispatch+2
 lda live_font_page
 sta $d409
 lda live_rock_color
 sta $d018
 lda live_mine_color
 sta $d016
 sta $d019
 lda live_door_colors+2
 sta $d017
 rts
nmi_exit:
 pla
 tay
 pla
 tax
 pla
 rti
.segment "RODATA"
fixed_dlist:
.byte $70,$70,$70,$70

dlrow0:
.byte 68,0,20
dlrow1:
.byte 68,40,20
dlrow2:
.byte 68,80,20
dlrow3:
.byte 68,120,20
dlrow4:
.byte 68,160,20
dlrow5:
.byte 68,200,20
dlrow6:
.byte 68,240,20
dlrow7:
.byte 68,24,21
dlrow8:
.byte 68,64,21
dlrow9:
.byte 196,104,21
dlrow10:
.byte 68,144,21
dlrow11:
.byte 68,184,21
dlrow12:
.byte 68,224,21
dlrow13:
.byte 68,8,22
dlrow14:
.byte 68,48,22
dlrow15:
.byte 68,88,22
dlrow16:
.byte 68,128,22
dlrow17:
.byte 68,168,22
dlrow18:
.byte 196,208,22
dlrow19:
.byte 68,248,22
dlrow20:
.byte 68,32,23
dlrow21:
.byte 196,72,23
dlrow22:
.byte 68,112,23
dlrow23:
.byte 68,152,23
.byte $4e,<bottom_row,>bottom_row,$4e,<bottom_row,>bottom_row,$ce,<bottom_row,>bottom_row,$41,<DLIST,>DLIST
fixed_dlist_end:
bottom_row:
.byte 0,0,85,85,85,85,85,85,85,85,85,85,85,85,85,85
.byte 85,85,85,85,85,85,85,85,85,85,85,85,85,85,85,85
.byte 85,85,85,85,85,85,80,0
keymap:
.byte $0e,$1e,$ff,$ff,$ff,$1f,$ff,$ff,$17,$ff,$0f,$15,$40,$16,$ff,$ff
.byte $24,$ff,$23,$ff,$ff,$25,$22,$21,$04,$ff,$03,$06,$ff,$05,$02,$01
.byte $ff,$0c,$ff,$2d,$ff,$26,$ff,$ff,$13,$ff,$12,$2c,$ff,$14,$11,$18
.byte $09,$ff,$00,$07,$ff,$08,$ff,$ff,$1b,$1d,$1a,$ff,$ff,$1c,$19,$20


base_map:
.byte 0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,4,0,0,0,4,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,8,9,10,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0
.byte 0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,11,12,13,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,4,0,0,0,4,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0
.byte 0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,4,0,0,0,4,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0
.byte 0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,4,0,0,0,4,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0
.byte 0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,4,0,0,0,4,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0
.byte 0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,8,9,10,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,4,0,0,0,4,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,11,12,13,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0
.byte 0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,4,0,0,0,4,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0
.byte 0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,4,0,0,0,4,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0
.byte 0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,4,0,0,0,4,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0
.byte 0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,4,0,0,0,4,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,8,9,10,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0
.byte 0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,11,12,13,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,4,0,0,0,4,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0
.byte 0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,4,0,0,0,4,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0
.byte 0,0,5,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,1,1,1,1,1,6,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
door_codes:
.byte 8,9,10,11,12,13,0,14,15,0,16,17
map_row_lo:
.byte 0,40,80,120,160,200,240,24,64,104,144,184,224,8,48,88
.byte 128,168,208,248,32,72,112,152,192
map_row_hi:
.byte 12,12,12,12,12,12,12,13,13,13,13,13,13,14,14,14
.byte 14,14,14,14,15,15,15,15,15
glyph_lo:
.byte 0,8,16,24,32,40,48,56,64,72,80,88,96,104,112,120
.byte 128,136,144,152,160,168,176,184,192,200,208,216,224,232,240,248
.byte 0,8,16,24,32,40,48,56,64,72,80,88,96,104,112,120
.byte 128,136,144,152,160,168,176,184,192,200,208,216,224,232,240,248
.byte 0,8,16,24,32,40,48,56,64,72,80,88,96,104,112,120
.byte 128,136,144,152,160,168,176,184,192,200,208,216,224,232,240,248
.byte 0,8,16,24,32,40,48,56,64,72,80,88,96,104,112,120
.byte 128,136,144,152,160,168,176,184,192,200,208,216,224,232,240,248
glyph_hi:
.byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
.byte 32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
.byte 33,33,33,33,33,33,33,33,33,33,33,33,33,33,33,33
.byte 33,33,33,33,33,33,33,33,33,33,33,33,33,33,33,33
.byte 34,34,34,34,34,34,34,34,34,34,34,34,34,34,34,34
.byte 34,34,34,34,34,34,34,34,34,34,34,34,34,34,34,34
.byte 35,35,35,35,35,35,35,35,35,35,35,35,35,35,35,35
.byte 35,35,35,35,35,35,35,35,35,35,35,35,35,35,35,35
stage_lo:
.byte 0,8,16,24,32,40,48,56,64,72,80,88,96,104,112,120
.byte 128,136,144,152,160,168,176,184,192,200,208,216,224,232,240,248
.byte 0,8,16,24,32,40,48,56,64,72,80,88,96
stage_hi:
.byte 5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5
.byte 5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5
.byte 6,6,6,6,6,6,6,6,6,6,6,6,6
static_font:
.byte 0,0,0,0,0,0,0,0,85,85,85,0,0,0,0,0
.byte 80,80,80,0,0,0,0,0,85,85,85,0,0,0,0,0
.byte 80,80,80,80,80,80,80,80,85,85,85,80,80,80,80,80
.byte 80,80,80,80,80,80,80,80,85,85,85,80,80,80,80,80
.byte 0,0,2,2,2,2,2,2,0,0,170,170,170,170,170,170
.byte 0,0,168,168,168,168,168,168,2,2,2,2,2,2,2,2
.byte 170,170,170,170,170,170,170,170,168,168,168,168,168,168,168,168
.byte 0,0,42,42,10,10,10,10,0,0,128,128,0,0,0,0
.byte 10,10,10,10,10,10,42,42,0,0,0,0,0,0,128,128
.byte 0,0,15,15,63,63,63,63,0,0,240,240,252,252,252,252
.byte 63,63,15,15,0,0,0,0,252,252,240,240,0,0,0,0
.byte 0,0,3,3,15,15,15,15,0,0,252,252,255,255,255,255
.byte 15,15,3,3,0,0,0,0,255,255,252,252,0,0,0,0
.byte 0,0,0,0,3,3,3,3,0,0,255,255,255,255,255,255
.byte 0,0,0,0,192,192,192,192,3,3,0,0,0,0,0,0
.byte 255,255,255,255,0,0,0,0,192,192,0,0,0,0,0,0
.byte 0,0,63,63,255,255,255,255,0,0,192,192,240,240,240,240
.byte 255,255,63,63,0,0,0,0,240,240,192,192,0,0,0,0
.byte 0,0,0,0,15,15,63,63,0,0,0,0,240,240,252,252
.byte 63,63,63,63,15,15,0,0,252,252,252,252,240,240,0,0
.byte 0,0,0,0,3,3,15,15,0,0,0,0,252,252,255,255
.byte 15,15,15,15,3,3,0,0,255,255,255,255,252,252,0,0
.byte 0,0,0,0,0,0,3,3,0,0,0,0,255,255,255,255
.byte 0,0,0,0,0,0,192,192,3,3,3,3,0,0,0,0
.byte 255,255,255,255,255,255,0,0,192,192,192,192,0,0,0,0
.byte 0,0,0,0,63,63,255,255,0,0,0,0,192,192,240,240
.byte 255,255,255,255,63,63,0,0,240,240,240,240,192,192,0,0
.byte 0,0,0,0,0,0,15,15,0,0,0,0,0,0,240,240
.byte 63,63,63,63,63,63,15,15,252,252,252,252,252,252,240,240
.byte 0,0,0,0,0,0,252,252,15,15,15,15,15,15,3,3
.byte 255,255,255,255,255,255,252,252,0,0,0,0,0,0,255,255
.byte 3,3,3,3,3,3,0,0,255,255,255,255,255,255,255,255
.byte 192,192,192,192,192,192,0,0,0,0,0,0,0,0,63,63
.byte 255,255,255,255,255,255,63,63,240,240,240,240,240,240,192,192
.byte 15,15,63,63,63,63,63,63,240,240,252,252,252,252,252,252
.byte 15,15,0,0,0,0,0,0,240,240,0,0,0,0,0,0
.byte 3,3,15,15,15,15,15,15,252,252,255,255,255,255,255,255
.byte 252,252,0,0,0,0,0,0,0,0,3,3,3,3,3,3
.byte 0,0,192,192,192,192,192,192,255,255,0,0,0,0,0,0
.byte 63,63,255,255,255,255,255,255,192,192,240,240,240,240,240,240
.byte 63,63,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,85,85,85,85,85,85,85,85
.byte 0,0,0,0,0,0,0,0,85,85,85,0,0,0,0,0
.byte 80,80,80,0,0,0,0,0,85,85,85,0,0,0,0,0
.byte 80,80,80,80,80,80,80,80,85,85,85,80,80,80,80,80
.byte 80,80,80,80,80,80,80,80,85,85,85,80,80,80,80,80
.byte 0,0,2,2,2,2,2,2,0,0,170,170,170,170,170,170
.byte 0,0,168,168,168,168,168,168,2,2,2,2,2,2,2,2
.byte 170,170,170,170,170,170,170,170,168,168,168,168,168,168,168,168
.byte 0,0,42,42,10,10,10,10,0,0,128,128,0,0,0,0
.byte 10,10,10,10,10,10,42,42,0,0,0,0,0,0,128,128
.byte 0,0,3,3,3,3,63,63,0,0,192,192,192,192,252,252
.byte 3,3,3,3,0,0,0,0,192,192,192,192,0,0,0,0
.byte 0,0,0,0,0,0,15,15,0,0,240,240,240,240,255,255
.byte 240,240,240,240,0,0,0,0,0,0,0,0,0,0,3,3
.byte 0,0,60,60,60,60,255,255,0,0,0,0,0,0,192,192
.byte 60,60,60,60,0,0,0,0,0,0,15,15,15,15,255,255
.byte 0,0,0,0,0,0,240,240,15,15,15,15,0,0,0,0
.byte 0,0,0,0,3,3,3,3,0,0,0,0,192,192,192,192
.byte 63,63,3,3,3,3,0,0,252,252,192,192,192,192,0,0
.byte 0,0,0,0,240,240,240,240,15,15,0,0,0,0,0,0
.byte 255,255,240,240,240,240,0,0,0,0,0,0,60,60,60,60
.byte 3,3,0,0,0,0,0,0,255,255,60,60,60,60,0,0
.byte 192,192,0,0,0,0,0,0,0,0,0,0,15,15,15,15
.byte 255,255,15,15,15,15,0,0,240,240,0,0,0,0,0,0
.byte 3,3,63,63,3,3,3,3,192,192,252,252,192,192,192,192
.byte 0,0,15,15,0,0,0,0,240,240,255,255,240,240,240,240
.byte 0,0,0,0,0,0,60,60,0,0,3,3,0,0,0,0
.byte 60,60,255,255,60,60,60,60,0,0,192,192,0,0,0,0
.byte 15,15,255,255,15,15,15,15,0,0,240,240,0,0,0,0
.byte 3,3,3,3,63,63,3,3,192,192,192,192,252,252,192,192
.byte 0,0,0,0,15,15,0,0,240,240,240,240,255,255,240,240
.byte 0,0,0,0,3,3,0,0,60,60,60,60,255,255,60,60
.byte 0,0,0,0,192,192,0,0,60,60,0,0,0,0,0,0
.byte 15,15,15,15,255,255,15,15,0,0,0,0,240,240,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,85,85,85,85,85,85,85,85
.byte 0,0,0,0,0,0,0,0,85,85,85,0,0,0,0,0
.byte 80,80,80,0,0,0,0,0,85,85,85,0,0,0,0,0
.byte 80,80,80,80,80,80,80,80,85,85,85,80,80,80,80,80
.byte 80,80,80,80,80,80,80,80,85,85,85,80,80,80,80,80
.byte 0,0,2,2,2,2,2,2,0,0,170,170,170,170,170,170
.byte 0,0,168,168,168,168,168,168,2,2,2,2,2,2,2,2
.byte 170,170,170,170,170,170,170,170,168,168,168,168,168,168,168,168
.byte 0,0,42,42,10,10,10,10,0,0,128,128,0,0,0,0
.byte 10,10,10,10,10,10,42,42,0,0,0,0,0,0,128,128
.byte 0,0,60,60,15,15,3,3,0,0,60,60,240,240,192,192
.byte 15,15,60,60,0,0,0,0,240,240,60,60,0,0,0,0
.byte 0,0,15,15,3,3,0,0,0,0,15,15,252,252,240,240
.byte 3,3,15,15,0,0,0,0,252,252,15,15,0,0,0,0
.byte 0,0,3,3,0,0,0,0,0,0,195,195,255,255,60,60
.byte 0,0,192,192,0,0,0,0,255,255,195,195,0,0,0,0
.byte 0,0,240,240,63,63,15,15,0,0,240,240,192,192,0,0
.byte 63,63,240,240,0,0,0,0,192,192,240,240,0,0,0,0
.byte 0,0,0,0,60,60,15,15,0,0,0,0,60,60,240,240
.byte 3,3,15,15,60,60,0,0,192,192,240,240,60,60,0,0
.byte 0,0,0,0,15,15,3,3,0,0,0,0,15,15,252,252
.byte 0,0,3,3,15,15,0,0,240,240,252,252,15,15,0,0
.byte 0,0,0,0,3,3,0,0,0,0,0,0,195,195,255,255
.byte 0,0,0,0,192,192,0,0,60,60,255,255,195,195,0,0
.byte 0,0,0,0,240,240,63,63,0,0,0,0,240,240,192,192
.byte 15,15,63,63,240,240,0,0,0,0,192,192,240,240,0,0
.byte 0,0,0,0,0,0,60,60,15,15,3,3,15,15,60,60
.byte 240,240,192,192,240,240,60,60,0,0,0,0,0,0,15,15
.byte 3,3,0,0,3,3,15,15,252,252,240,240,252,252,15,15
.byte 0,0,0,0,0,0,3,3,0,0,0,0,0,0,195,195
.byte 0,0,0,0,0,0,192,192,255,255,60,60,255,255,195,195
.byte 0,0,0,0,0,0,240,240,63,63,15,15,63,63,240,240
.byte 192,192,0,0,192,192,240,240,60,60,15,15,3,3,15,15
.byte 60,60,240,240,192,192,240,240,60,60,0,0,0,0,0,0
.byte 15,15,3,3,0,0,3,3,15,15,252,252,240,240,252,252
.byte 15,15,0,0,0,0,0,0,3,3,0,0,0,0,0,0
.byte 195,195,255,255,60,60,255,255,192,192,0,0,0,0,0,0
.byte 195,195,0,0,0,0,0,0,240,240,63,63,15,15,63,63
.byte 240,240,192,192,0,0,192,192,240,240,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.byte 0,0,0,0,0,0,0,0,85,85,85,85,85,85,85,85
rock_tile_codes:
.byte 18,19,0,20,21,0,0,0,0,22,23,0,24,25,0,0
.byte 0,0,26,27,28,29,30,31,0,0,0,0,32,33,0,34
.byte 35,0,0,0,18,19,0,20,21,0,0,0,0,22,23,0
.byte 24,25,0,0,0,0,26,27,28,29,30,31,0,0,0,0
.byte 32,33,0,34,35,0,0,0,36,37,0,38,39,0,0,0
.byte 0,40,41,0,42,43,0,0,0,0,44,45,46,47,48,49
.byte 0,0,0,0,50,51,0,52,53,0,0,0,36,37,0,38
.byte 39,0,0,0,0,40,41,0,42,43,0,0,0,0,44,45
.byte 46,47,48,49,0,0,0,0,50,51,0,52,53,0,0,0
.byte 54,55,0,56,57,0,0,0,0,44,58,0,59,60,0,0
.byte 0,0,0,61,0,62,63,64,0,0,0,0,65,46,0,66
.byte 67,0,0,0,54,55,0,56,57,0,0,0,0,44,58,0
.byte 59,60,0,0,0,0,0,61,0,62,63,64,0,0,0,0
.byte 65,46,0,66,67,0,0,0,0,0,0,68,69,0,70,71
.byte 0,0,0,0,72,73,0,29,74,0,0,0,0,75,63,76
.byte 0,77,0,0,0,0,0,78,79,0,80,31,0,0,0,68
.byte 69,0,70,71,0,0,0,0,72,73,0,29,74,0,0,0
.byte 0,75,63,76,0,77,0,0,0,0,0,78,79,0,80,31
.byte 18,19,0,20,21,0,0,0,0,22,23,0,0,24,0,0
.byte 0,0,25,26,27,0,28,0,0,0,0,0,29,30,0,31
.byte 0,0,0,0,18,19,0,20,21,0,0,0,0,22,23,0
.byte 0,24,0,0,0,0,25,26,27,0,28,0,0,0,0,0
.byte 29,30,0,31,0,0,0,0,32,33,0,34,35,0,0,0
.byte 0,0,36,0,37,38,0,0,0,0,0,39,0,40,41,42
.byte 0,0,0,0,43,0,0,44,45,0,0,0,32,33,0,34
.byte 35,0,0,0,0,0,36,0,37,38,0,0,0,0,0,39
.byte 0,40,41,42,0,0,0,0,43,0,0,44,45,0,0,0
.byte 25,27,0,46,47,0,0,0,0,0,30,0,48,49,0,0
.byte 0,0,0,50,0,51,52,53,0,0,0,0,22,0,0,54
.byte 55,0,0,0,25,27,0,46,47,0,0,0,0,0,30,0
.byte 48,49,0,0,0,0,0,50,0,51,52,53,0,0,0,0
.byte 22,0,0,54,55,0,0,0,0,0,0,56,57,0,40,42
.byte 0,0,0,0,58,59,0,0,45,0,0,0,0,60,61,62
.byte 0,63,0,0,0,0,0,64,65,0,37,0,0,0,0,56
.byte 57,0,40,42,0,0,0,0,58,59,0,0,45,0,0,0
.byte 0,60,61,62,0,63,0,0,0,0,0,64,65,0,37,0
.byte 18,19,0,20,21,0,0,0,0,22,23,0,24,25,0,0
.byte 0,0,26,27,28,26,29,28,0,0,0,0,30,31,0,32
.byte 33,0,0,0,18,19,0,20,21,0,0,0,0,22,23,0
.byte 24,25,0,0,0,0,26,27,28,26,29,28,0,0,0,0
.byte 30,31,0,32,33,0,0,0,34,35,0,36,37,0,0,0
.byte 0,38,39,0,40,41,0,0,0,0,42,43,44,42,45,44
.byte 0,0,0,0,46,47,0,48,49,0,0,0,34,35,0,36
.byte 37,0,0,0,0,38,39,0,40,41,0,0,0,0,42,43
.byte 44,42,45,44,0,0,0,0,46,47,0,48,49,0,0,0
.byte 50,50,0,51,52,0,0,0,0,53,53,0,54,55,0,0
.byte 0,0,56,57,58,56,59,58,0,0,0,0,60,60,0,61
.byte 62,0,0,0,50,50,0,51,52,0,0,0,0,53,53,0
.byte 54,55,0,0,0,0,56,57,58,56,59,58,0,0,0,0
.byte 60,60,0,61,62,0,0,0,0,0,0,63,64,0,65,65
.byte 0,0,0,0,66,67,0,68,68,0,0,0,0,69,70,71
.byte 69,72,71,0,0,0,0,73,74,0,75,75,0,0,0,63
.byte 64,0,65,65,0,0,0,0,66,67,0,68,68,0,0,0
.byte 0,69,70,71,69,72,71,0,0,0,0,73,74,0,75,75
shift_lo:
.byte <(rock_tile_codes+0),<(rock_tile_codes+9),<(rock_tile_codes+18),<(rock_tile_codes+27),<(rock_tile_codes+36),<(rock_tile_codes+45),<(rock_tile_codes+54),<(rock_tile_codes+63),<(rock_tile_codes+72),<(rock_tile_codes+81),<(rock_tile_codes+90),<(rock_tile_codes+99),<(rock_tile_codes+108),<(rock_tile_codes+117),<(rock_tile_codes+126),<(rock_tile_codes+135),<(rock_tile_codes+144),<(rock_tile_codes+153),<(rock_tile_codes+162),<(rock_tile_codes+171),<(rock_tile_codes+180),<(rock_tile_codes+189),<(rock_tile_codes+198),<(rock_tile_codes+207),<(rock_tile_codes+216),<(rock_tile_codes+225),<(rock_tile_codes+234),<(rock_tile_codes+243),<(rock_tile_codes+252),<(rock_tile_codes+261),<(rock_tile_codes+270),<(rock_tile_codes+279),<(rock_tile_codes+288),<(rock_tile_codes+297),<(rock_tile_codes+306),<(rock_tile_codes+315),<(rock_tile_codes+324),<(rock_tile_codes+333),<(rock_tile_codes+342),<(rock_tile_codes+351),<(rock_tile_codes+360),<(rock_tile_codes+369),<(rock_tile_codes+378),<(rock_tile_codes+387),<(rock_tile_codes+396),<(rock_tile_codes+405),<(rock_tile_codes+414),<(rock_tile_codes+423),<(rock_tile_codes+432),<(rock_tile_codes+441),<(rock_tile_codes+450),<(rock_tile_codes+459),<(rock_tile_codes+468),<(rock_tile_codes+477),<(rock_tile_codes+486),<(rock_tile_codes+495),<(rock_tile_codes+504),<(rock_tile_codes+513),<(rock_tile_codes+522),<(rock_tile_codes+531),<(rock_tile_codes+540),<(rock_tile_codes+549),<(rock_tile_codes+558),<(rock_tile_codes+567),<(rock_tile_codes+576),<(rock_tile_codes+585),<(rock_tile_codes+594),<(rock_tile_codes+603),<(rock_tile_codes+612),<(rock_tile_codes+621),<(rock_tile_codes+630),<(rock_tile_codes+639),<(rock_tile_codes+648),<(rock_tile_codes+657),<(rock_tile_codes+666),<(rock_tile_codes+675),<(rock_tile_codes+684),<(rock_tile_codes+693),<(rock_tile_codes+702),<(rock_tile_codes+711),<(rock_tile_codes+720),<(rock_tile_codes+729),<(rock_tile_codes+738),<(rock_tile_codes+747),<(rock_tile_codes+756),<(rock_tile_codes+765),<(rock_tile_codes+774),<(rock_tile_codes+783),<(rock_tile_codes+792),<(rock_tile_codes+801),<(rock_tile_codes+810),<(rock_tile_codes+819),<(rock_tile_codes+828),<(rock_tile_codes+837),<(rock_tile_codes+846),<(rock_tile_codes+855)
shift_hi:
.byte >(rock_tile_codes+0),>(rock_tile_codes+9),>(rock_tile_codes+18),>(rock_tile_codes+27),>(rock_tile_codes+36),>(rock_tile_codes+45),>(rock_tile_codes+54),>(rock_tile_codes+63),>(rock_tile_codes+72),>(rock_tile_codes+81),>(rock_tile_codes+90),>(rock_tile_codes+99),>(rock_tile_codes+108),>(rock_tile_codes+117),>(rock_tile_codes+126),>(rock_tile_codes+135),>(rock_tile_codes+144),>(rock_tile_codes+153),>(rock_tile_codes+162),>(rock_tile_codes+171),>(rock_tile_codes+180),>(rock_tile_codes+189),>(rock_tile_codes+198),>(rock_tile_codes+207),>(rock_tile_codes+216),>(rock_tile_codes+225),>(rock_tile_codes+234),>(rock_tile_codes+243),>(rock_tile_codes+252),>(rock_tile_codes+261),>(rock_tile_codes+270),>(rock_tile_codes+279),>(rock_tile_codes+288),>(rock_tile_codes+297),>(rock_tile_codes+306),>(rock_tile_codes+315),>(rock_tile_codes+324),>(rock_tile_codes+333),>(rock_tile_codes+342),>(rock_tile_codes+351),>(rock_tile_codes+360),>(rock_tile_codes+369),>(rock_tile_codes+378),>(rock_tile_codes+387),>(rock_tile_codes+396),>(rock_tile_codes+405),>(rock_tile_codes+414),>(rock_tile_codes+423),>(rock_tile_codes+432),>(rock_tile_codes+441),>(rock_tile_codes+450),>(rock_tile_codes+459),>(rock_tile_codes+468),>(rock_tile_codes+477),>(rock_tile_codes+486),>(rock_tile_codes+495),>(rock_tile_codes+504),>(rock_tile_codes+513),>(rock_tile_codes+522),>(rock_tile_codes+531),>(rock_tile_codes+540),>(rock_tile_codes+549),>(rock_tile_codes+558),>(rock_tile_codes+567),>(rock_tile_codes+576),>(rock_tile_codes+585),>(rock_tile_codes+594),>(rock_tile_codes+603),>(rock_tile_codes+612),>(rock_tile_codes+621),>(rock_tile_codes+630),>(rock_tile_codes+639),>(rock_tile_codes+648),>(rock_tile_codes+657),>(rock_tile_codes+666),>(rock_tile_codes+675),>(rock_tile_codes+684),>(rock_tile_codes+693),>(rock_tile_codes+702),>(rock_tile_codes+711),>(rock_tile_codes+720),>(rock_tile_codes+729),>(rock_tile_codes+738),>(rock_tile_codes+747),>(rock_tile_codes+756),>(rock_tile_codes+765),>(rock_tile_codes+774),>(rock_tile_codes+783),>(rock_tile_codes+792),>(rock_tile_codes+801),>(rock_tile_codes+810),>(rock_tile_codes+819),>(rock_tile_codes+828),>(rock_tile_codes+837),>(rock_tile_codes+846),>(rock_tile_codes+855)
composite_data:
.byte 85,85,85,0,0,0,0,0,85,85,85,80,80,80,80,80
.byte 85,85,87,2,2,2,2,2,85,85,255,170,170,170,170,170
.byte 85,85,253,168,168,168,168,168,87,87,87,2,2,2,2,2
.byte 255,255,255,170,170,170,170,170,253,253,253,168,168,168,168,168
.byte 85,85,127,42,10,10,10,10,85,85,213,128,0,0,0,0
.byte 95,95,95,10,10,10,42,42,85,85,85,0,0,0,128,128
.byte 85,85,95,15,63,63,63,63,85,85,245,240,252,252,252,252
.byte 127,127,95,15,0,0,0,0,253,253,245,240,0,0,0,0
.byte 85,85,87,3,15,15,15,15,85,85,253,252,255,255,255,255
.byte 95,95,87,3,0,0,0,0,255,255,253,252,0,0,0,0
.byte 85,85,85,0,3,3,3,3,85,85,255,255,255,255,255,255
.byte 85,85,85,0,192,192,192,192,87,87,85,0,0,0,0,0
.byte 255,255,255,255,0,0,0,0,213,213,85,0,0,0,0,0
.byte 85,85,127,63,255,255,255,255,85,85,213,192,240,240,240,240
.byte 255,255,127,63,0,0,0,0,245,245,213,192,0,0,0,0
.byte 85,85,85,0,15,15,63,63,85,85,85,0,240,240,252,252
.byte 127,127,127,63,15,15,0,0,253,253,253,252,240,240,0,0
.byte 85,85,85,0,3,3,15,15,85,85,85,0,252,252,255,255
.byte 95,95,95,15,3,3,0,0,255,255,255,255,252,252,0,0
.byte 85,85,85,0,0,0,3,3,85,85,85,0,255,255,255,255
.byte 85,85,85,0,0,0,192,192,87,87,87,3,0,0,0,0
.byte 255,255,255,255,255,255,0,0,213,213,213,192,0,0,0,0
.byte 85,85,85,0,63,63,255,255,85,85,85,0,192,192,240,240
.byte 255,255,255,255,63,63,0,0,245,245,245,240,192,192,0,0
.byte 85,85,85,0,0,0,15,15,85,85,85,0,0,0,240,240
.byte 127,127,127,63,63,63,15,15,253,253,253,252,252,252,240,240
.byte 85,85,85,0,0,0,252,252,95,95,95,15,15,15,3,3
.byte 255,255,255,255,255,255,252,252,85,85,85,0,0,0,255,255
.byte 87,87,87,3,3,3,0,0,255,255,255,255,255,255,255,255
.byte 213,213,213,192,192,192,0,0,85,85,85,0,0,0,63,63
.byte 255,255,255,255,255,255,63,63,245,245,245,240,240,240,192,192
.byte 95,95,127,63,63,63,63,63,245,245,253,252,252,252,252,252
.byte 95,95,85,0,0,0,0,0,245,245,85,0,0,0,0,0
.byte 87,87,95,15,15,15,15,15,253,253,255,255,255,255,255,255
.byte 253,253,85,0,0,0,0,0,85,85,87,3,3,3,3,3
.byte 85,85,213,192,192,192,192,192,255,255,85,0,0,0,0,0
.byte 127,127,255,255,255,255,255,255,213,213,245,240,240,240,240,240
.byte 127,127,85,0,0,0,0,0,80,80,80,0,0,0,0,0
.byte 80,80,80,80,80,80,80,80,80,80,82,2,2,2,2,2
.byte 80,80,250,170,170,170,170,170,80,80,248,168,168,168,168,168
.byte 82,82,82,2,2,2,2,2,250,250,250,170,170,170,170,170
.byte 248,248,248,168,168,168,168,168,80,80,122,42,10,10,10,10
.byte 80,80,208,128,0,0,0,0,90,90,90,10,10,10,42,42
.byte 80,80,80,0,0,0,128,128,80,80,95,15,63,63,63,63
.byte 80,80,240,240,252,252,252,252,252,252,240,240,0,0,0,0
.byte 80,80,83,3,15,15,15,15,80,80,252,252,255,255,255,255
.byte 95,95,83,3,0,0,0,0,255,255,252,252,0,0,0,0
.byte 80,80,80,0,3,3,3,3,80,80,255,255,255,255,255,255
.byte 80,80,80,0,192,192,192,192,83,83,80,0,0,0,0,0
.byte 208,208,80,0,0,0,0,0,80,80,127,63,255,255,255,255
.byte 80,80,208,192,240,240,240,240,240,240,208,192,0,0,0,0
.byte 80,80,80,0,15,15,63,63,80,80,80,0,240,240,252,252
.byte 252,252,252,252,240,240,0,0,80,80,80,0,3,3,15,15
.byte 80,80,80,0,252,252,255,255,80,80,80,0,0,0,3,3
.byte 80,80,80,0,255,255,255,255,80,80,80,0,0,0,192,192
.byte 83,83,83,3,0,0,0,0,208,208,208,192,0,0,0,0
.byte 80,80,80,0,63,63,255,255,80,80,80,0,192,192,240,240
.byte 240,240,240,240,192,192,0,0,80,80,80,0,0,0,15,15
.byte 80,80,80,0,0,0,240,240,252,252,252,252,252,252,240,240
.byte 80,80,80,0,0,0,252,252,80,80,80,0,0,0,255,255
.byte 83,83,83,3,3,3,0,0,208,208,208,192,192,192,0,0
.byte 80,80,80,0,0,0,63,63,240,240,240,240,240,240,192,192
.byte 240,240,252,252,252,252,252,252,95,95,80,0,0,0,0,0
.byte 240,240,80,0,0,0,0,0,83,83,95,15,15,15,15,15
.byte 252,252,255,255,255,255,255,255,252,252,80,0,0,0,0,0
.byte 80,80,83,3,3,3,3,3,80,80,208,192,192,192,192,192
.byte 255,255,80,0,0,0,0,0,208,208,240,240,240,240,240,240
.byte 127,127,80,0,0,0,0,0,80,80,82,82,82,82,82,82
.byte 80,80,250,250,250,250,250,250,80,80,248,248,248,248,248,248
.byte 82,82,82,82,82,82,82,82,250,250,250,250,250,250,250,250
.byte 248,248,248,248,248,248,248,248,80,80,122,122,90,90,90,90
.byte 80,80,208,208,80,80,80,80,90,90,90,90,90,90,122,122
.byte 80,80,80,80,80,80,208,208,80,80,95,95,127,127,127,127
.byte 127,127,95,95,80,80,80,80,252,252,240,240,80,80,80,80
.byte 80,80,83,83,95,95,95,95,95,95,83,83,80,80,80,80
.byte 255,255,252,252,80,80,80,80,80,80,80,80,83,83,83,83
.byte 80,80,80,80,208,208,208,208,83,83,80,80,80,80,80,80
.byte 255,255,255,255,80,80,80,80,208,208,80,80,80,80,80,80
.byte 80,80,127,127,255,255,255,255,80,80,208,208,240,240,240,240
.byte 255,255,127,127,80,80,80,80,240,240,208,208,80,80,80,80
.byte 80,80,80,80,95,95,127,127,80,80,80,80,240,240,252,252
.byte 127,127,127,127,95,95,80,80,252,252,252,252,240,240,80,80
.byte 80,80,80,80,83,83,95,95,80,80,80,80,252,252,255,255
.byte 95,95,95,95,83,83,80,80,255,255,255,255,252,252,80,80
.byte 80,80,80,80,80,80,83,83,80,80,80,80,255,255,255,255
.byte 83,83,83,83,80,80,80,80,255,255,255,255,255,255,80,80
.byte 208,208,208,208,80,80,80,80,80,80,80,80,127,127,255,255
.byte 80,80,80,80,208,208,240,240,255,255,255,255,127,127,80,80
.byte 240,240,240,240,208,208,80,80,80,80,80,80,80,80,95,95
.byte 80,80,80,80,80,80,240,240,127,127,127,127,127,127,95,95
.byte 80,80,80,80,80,80,252,252,95,95,95,95,95,95,83,83
.byte 80,80,80,80,80,80,255,255,83,83,83,83,83,83,80,80
.byte 208,208,208,208,208,208,80,80,80,80,80,80,80,80,127,127
.byte 255,255,255,255,255,255,127,127,240,240,240,240,240,240,208,208
.byte 95,95,127,127,127,127,127,127,95,95,80,80,80,80,80,80
.byte 240,240,80,80,80,80,80,80,83,83,95,95,95,95,95,95
.byte 252,252,80,80,80,80,80,80,80,80,83,83,83,83,83,83
.byte 80,80,208,208,208,208,208,208,255,255,80,80,80,80,80,80
.byte 127,127,80,80,80,80,80,80,85,85,87,82,82,82,82,82
.byte 85,85,255,250,250,250,250,250,85,85,253,248,248,248,248,248
.byte 87,87,87,82,82,82,82,82,255,255,255,250,250,250,250,250
.byte 253,253,253,248,248,248,248,248,85,85,127,122,90,90,90,90
.byte 85,85,213,208,80,80,80,80,95,95,95,90,90,90,122,122
.byte 85,85,85,80,80,80,208,208,85,85,95,95,127,127,127,127
.byte 253,253,245,240,80,80,80,80,85,85,87,83,95,95,95,95
.byte 95,95,87,83,80,80,80,80,255,255,253,252,80,80,80,80
.byte 85,85,85,80,83,83,83,83,85,85,85,80,208,208,208,208
.byte 87,87,85,80,80,80,80,80,213,213,85,80,80,80,80,80
.byte 85,85,127,127,255,255,255,255,85,85,213,208,240,240,240,240
.byte 245,245,213,208,80,80,80,80,85,85,85,80,95,95,127,127
.byte 85,85,85,80,240,240,252,252,253,253,253,252,240,240,80,80
.byte 85,85,85,80,83,83,95,95,85,85,85,80,252,252,255,255
.byte 85,85,85,80,80,80,83,83,85,85,85,80,255,255,255,255
.byte 87,87,87,83,80,80,80,80,213,213,213,208,80,80,80,80
.byte 85,85,85,80,127,127,255,255,85,85,85,80,208,208,240,240
.byte 245,245,245,240,208,208,80,80,85,85,85,80,80,80,95,95
.byte 85,85,85,80,80,80,240,240,85,85,85,80,80,80,252,252
.byte 85,85,85,80,80,80,255,255,87,87,87,83,83,83,80,80
.byte 213,213,213,208,208,208,80,80,85,85,85,80,80,80,127,127
.byte 245,245,245,240,240,240,208,208,95,95,85,80,80,80,80,80
.byte 245,245,85,80,80,80,80,80,87,87,95,95,95,95,95,95
.byte 253,253,85,80,80,80,80,80,85,85,87,83,83,83,83,83
.byte 85,85,213,208,208,208,208,208,255,255,85,80,80,80,80,80
.byte 127,127,85,80,80,80,80,80,85,85,87,3,3,3,63,63
.byte 85,85,213,192,192,192,252,252,85,85,245,240,240,240,255,255
.byte 245,245,245,240,0,0,0,0,85,85,125,60,60,60,255,255
.byte 125,125,125,60,0,0,0,0,85,85,95,15,15,15,255,255
.byte 95,95,95,15,0,0,0,0,127,127,87,3,3,3,0,0
.byte 253,253,213,192,192,192,0,0,85,85,85,0,240,240,240,240
.byte 255,255,245,240,240,240,0,0,85,85,85,0,60,60,60,60
.byte 255,255,125,60,60,60,0,0,85,85,85,0,15,15,15,15
.byte 255,255,95,15,15,15,0,0,87,87,127,63,3,3,3,3
.byte 213,213,253,252,192,192,192,192,85,85,95,15,0,0,0,0
.byte 245,245,255,255,240,240,240,240,85,85,85,0,0,0,60,60
.byte 85,85,87,3,0,0,0,0,125,125,255,255,60,60,60,60
.byte 85,85,213,192,0,0,0,0,95,95,255,255,15,15,15,15
.byte 85,85,245,240,0,0,0,0,87,87,87,3,63,63,3,3
.byte 213,213,213,192,252,252,192,192,85,85,85,0,15,15,0,0
.byte 245,245,245,240,255,255,240,240,85,85,85,0,3,3,0,0
.byte 125,125,125,60,255,255,60,60,85,85,85,0,192,192,0,0
.byte 125,125,85,0,0,0,0,0,95,95,95,15,255,255,15,15
.byte 85,85,85,0,240,240,0,0,80,80,83,3,3,3,63,63
.byte 80,80,208,192,192,192,252,252,80,80,240,240,240,240,255,255
.byte 240,240,240,240,0,0,0,0,80,80,124,60,60,60,255,255
.byte 124,124,124,60,0,0,0,0,80,80,95,15,15,15,255,255
.byte 127,127,83,3,3,3,0,0,252,252,208,192,192,192,0,0
.byte 80,80,80,0,240,240,240,240,255,255,240,240,240,240,0,0
.byte 80,80,80,0,60,60,60,60,255,255,124,60,60,60,0,0
.byte 80,80,80,0,15,15,15,15,83,83,127,63,3,3,3,3
.byte 208,208,252,252,192,192,192,192,80,80,95,15,0,0,0,0
.byte 240,240,255,255,240,240,240,240,80,80,80,0,0,0,60,60
.byte 80,80,83,3,0,0,0,0,124,124,255,255,60,60,60,60
.byte 80,80,208,192,0,0,0,0,80,80,240,240,0,0,0,0
.byte 83,83,83,3,63,63,3,3,208,208,208,192,252,252,192,192
.byte 80,80,80,0,15,15,0,0,240,240,240,240,255,255,240,240
.byte 80,80,80,0,3,3,0,0,124,124,124,60,255,255,60,60
.byte 80,80,80,0,192,192,0,0,124,124,80,0,0,0,0,0
.byte 80,80,80,0,240,240,0,0,80,80,83,83,83,83,127,127
.byte 80,80,208,208,208,208,252,252,240,240,240,240,80,80,80,80
.byte 80,80,124,124,124,124,255,255,124,124,124,124,80,80,80,80
.byte 80,80,95,95,95,95,255,255,95,95,95,95,80,80,80,80
.byte 127,127,83,83,83,83,80,80,252,252,208,208,208,208,80,80
.byte 80,80,80,80,240,240,240,240,255,255,240,240,240,240,80,80
.byte 80,80,80,80,124,124,124,124,255,255,124,124,124,124,80,80
.byte 80,80,80,80,95,95,95,95,255,255,95,95,95,95,80,80
.byte 83,83,127,127,83,83,83,83,208,208,252,252,208,208,208,208
.byte 80,80,95,95,80,80,80,80,80,80,80,80,80,80,124,124
.byte 80,80,83,83,80,80,80,80,124,124,255,255,124,124,124,124
.byte 95,95,255,255,95,95,95,95,80,80,240,240,80,80,80,80
.byte 83,83,83,83,127,127,83,83,208,208,208,208,252,252,208,208
.byte 80,80,80,80,95,95,80,80,80,80,80,80,83,83,80,80
.byte 124,124,124,124,255,255,124,124,80,80,80,80,208,208,80,80
.byte 124,124,80,80,80,80,80,80,95,95,95,95,255,255,95,95
.byte 80,80,80,80,240,240,80,80,85,85,87,83,83,83,127,127
.byte 85,85,213,208,208,208,252,252,245,245,245,240,80,80,80,80
.byte 85,85,125,124,124,124,255,255,125,125,125,124,80,80,80,80
.byte 85,85,95,95,95,95,255,255,127,127,87,83,83,83,80,80
.byte 253,253,213,208,208,208,80,80,85,85,85,80,240,240,240,240
.byte 255,255,245,240,240,240,80,80,85,85,85,80,124,124,124,124
.byte 255,255,125,124,124,124,80,80,85,85,85,80,95,95,95,95
.byte 87,87,127,127,83,83,83,83,213,213,253,252,208,208,208,208
.byte 85,85,95,95,80,80,80,80,85,85,85,80,80,80,124,124
.byte 85,85,87,83,80,80,80,80,125,125,255,255,124,124,124,124
.byte 85,85,245,240,80,80,80,80,87,87,87,83,127,127,83,83
.byte 213,213,213,208,252,252,208,208,85,85,85,80,95,95,80,80
.byte 85,85,85,80,83,83,80,80,125,125,125,124,255,255,124,124
.byte 85,85,85,80,208,208,80,80,125,125,85,80,80,80,80,80
.byte 85,85,85,80,240,240,80,80,85,85,125,60,15,15,3,3
.byte 85,85,125,60,240,240,192,192,95,95,125,60,0,0,0,0
.byte 245,245,125,60,0,0,0,0,85,85,95,15,3,3,0,0
.byte 85,85,95,15,252,252,240,240,87,87,95,15,0,0,0,0
.byte 253,253,95,15,0,0,0,0,85,85,215,195,255,255,60,60
.byte 255,255,215,195,0,0,0,0,85,85,245,240,63,63,15,15
.byte 85,85,245,240,192,192,0,0,127,127,245,240,0,0,0,0
.byte 213,213,245,240,0,0,0,0,85,85,85,0,60,60,15,15
.byte 85,85,85,0,60,60,240,240,87,87,95,15,60,60,0,0
.byte 213,213,245,240,60,60,0,0,85,85,85,0,15,15,3,3
.byte 85,85,85,0,15,15,252,252,85,85,87,3,15,15,0,0
.byte 245,245,253,252,15,15,0,0,85,85,85,0,195,195,255,255
.byte 125,125,255,255,195,195,0,0,85,85,85,0,240,240,63,63
.byte 85,85,85,0,240,240,192,192,95,95,127,63,240,240,0,0
.byte 85,85,213,192,240,240,0,0,95,95,87,3,15,15,60,60
.byte 245,245,213,192,240,240,60,60,87,87,85,0,3,3,15,15
.byte 253,253,245,240,252,252,15,15,85,85,85,0,0,0,195,195
.byte 255,255,125,60,255,255,195,195,127,127,95,15,63,63,240,240
.byte 213,213,85,0,192,192,240,240,125,125,95,15,3,3,15,15
.byte 125,125,245,240,192,192,240,240,95,95,87,3,0,0,3,3
.byte 95,95,253,252,240,240,252,252,215,215,255,255,60,60,255,255
.byte 215,215,85,0,0,0,0,0,245,245,127,63,15,15,63,63
.byte 245,245,213,192,0,0,192,192,80,80,124,60,15,15,3,3
.byte 80,80,124,60,240,240,192,192,95,95,124,60,0,0,0,0
.byte 240,240,124,60,0,0,0,0,80,80,95,15,3,3,0,0
.byte 80,80,95,15,252,252,240,240,83,83,95,15,0,0,0,0
.byte 252,252,95,15,0,0,0,0,80,80,211,195,255,255,60,60
.byte 255,255,211,195,0,0,0,0,80,80,240,240,63,63,15,15
.byte 80,80,240,240,192,192,0,0,127,127,240,240,0,0,0,0
.byte 208,208,240,240,0,0,0,0,80,80,80,0,60,60,15,15
.byte 80,80,80,0,60,60,240,240,83,83,95,15,60,60,0,0
.byte 208,208,240,240,60,60,0,0,80,80,80,0,15,15,3,3
.byte 80,80,80,0,15,15,252,252,80,80,83,3,15,15,0,0
.byte 240,240,252,252,15,15,0,0,80,80,80,0,195,195,255,255
.byte 124,124,255,255,195,195,0,0,80,80,80,0,240,240,63,63
.byte 80,80,80,0,240,240,192,192,80,80,208,192,240,240,0,0
.byte 95,95,83,3,15,15,60,60,240,240,208,192,240,240,60,60
.byte 83,83,80,0,3,3,15,15,252,252,240,240,252,252,15,15
.byte 80,80,80,0,0,0,195,195,255,255,124,60,255,255,195,195
.byte 208,208,80,0,192,192,240,240,124,124,95,15,3,3,15,15
.byte 124,124,240,240,192,192,240,240,95,95,83,3,0,0,3,3
.byte 95,95,252,252,240,240,252,252,211,211,255,255,60,60,255,255
.byte 211,211,80,0,0,0,0,0,240,240,127,63,15,15,63,63
.byte 240,240,208,192,0,0,192,192,80,80,124,124,95,95,83,83
.byte 80,80,124,124,240,240,208,208,95,95,124,124,80,80,80,80
.byte 240,240,124,124,80,80,80,80,80,80,95,95,83,83,80,80
.byte 80,80,95,95,252,252,240,240,83,83,95,95,80,80,80,80
.byte 252,252,95,95,80,80,80,80,80,80,211,211,255,255,124,124
.byte 255,255,211,211,80,80,80,80,80,80,240,240,127,127,95,95
.byte 80,80,240,240,208,208,80,80,127,127,240,240,80,80,80,80
.byte 208,208,240,240,80,80,80,80,80,80,80,80,124,124,95,95
.byte 80,80,80,80,124,124,240,240,83,83,95,95,124,124,80,80
.byte 208,208,240,240,124,124,80,80,80,80,80,80,95,95,83,83
.byte 80,80,80,80,95,95,252,252,80,80,83,83,95,95,80,80
.byte 240,240,252,252,95,95,80,80,80,80,80,80,211,211,255,255
.byte 124,124,255,255,211,211,80,80,80,80,80,80,240,240,127,127
.byte 80,80,80,80,240,240,208,208,95,95,127,127,240,240,80,80
.byte 80,80,208,208,240,240,80,80,95,95,83,83,95,95,124,124
.byte 240,240,208,208,240,240,124,124,83,83,80,80,83,83,95,95
.byte 252,252,240,240,252,252,95,95,80,80,80,80,80,80,211,211
.byte 255,255,124,124,255,255,211,211,127,127,95,95,127,127,240,240
.byte 208,208,80,80,208,208,240,240,124,124,95,95,83,83,95,95
.byte 124,124,240,240,208,208,240,240,95,95,83,83,80,80,83,83
.byte 211,211,255,255,124,124,255,255,211,211,80,80,80,80,80,80
.byte 240,240,127,127,95,95,127,127,240,240,208,208,80,80,208,208
.byte 85,85,125,124,95,95,83,83,85,85,125,124,240,240,208,208
.byte 95,95,125,124,80,80,80,80,245,245,125,124,80,80,80,80
.byte 85,85,95,95,83,83,80,80,85,85,95,95,252,252,240,240
.byte 87,87,95,95,80,80,80,80,253,253,95,95,80,80,80,80
.byte 85,85,215,211,255,255,124,124,255,255,215,211,80,80,80,80
.byte 85,85,245,240,127,127,95,95,85,85,245,240,208,208,80,80
.byte 127,127,245,240,80,80,80,80,213,213,245,240,80,80,80,80
.byte 85,85,85,80,124,124,95,95,85,85,85,80,124,124,240,240
.byte 87,87,95,95,124,124,80,80,213,213,245,240,124,124,80,80
.byte 85,85,85,80,95,95,83,83,85,85,85,80,95,95,252,252
.byte 85,85,87,83,95,95,80,80,245,245,253,252,95,95,80,80
.byte 85,85,85,80,211,211,255,255,125,125,255,255,211,211,80,80
.byte 85,85,85,80,240,240,127,127,85,85,85,80,240,240,208,208
.byte 85,85,213,208,240,240,80,80,95,95,87,83,95,95,124,124
.byte 245,245,213,208,240,240,124,124,87,87,85,80,83,83,95,95
.byte 253,253,245,240,252,252,95,95,85,85,85,80,80,80,211,211
.byte 255,255,125,124,255,255,211,211,213,213,85,80,208,208,240,240
.byte 125,125,95,95,83,83,95,95,125,125,245,240,208,208,240,240
.byte 95,95,87,83,80,80,83,83,215,215,255,255,124,124,255,255
.byte 215,215,85,80,80,80,80,80,245,245,127,127,95,95,127,127
.byte 245,245,213,208,80,80,208,208
composite_row_0:
.byte <(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+16),<(composite_data+24),<(composite_data+32),<(composite_data+40),<(composite_data+48),<(composite_data+56),<(composite_data+64),<(composite_data+72),<(composite_data+80),<(composite_data+88),<(composite_data+96),<(composite_data+104),<(composite_data+112),<(composite_data+120),<(composite_data+128),<(composite_data+136),<(composite_data+144),<(composite_data+152),<(composite_data+160),<(composite_data+168),<(composite_data+176),<(composite_data+184),<(composite_data+192),<(composite_data+200),<(composite_data+208),<(composite_data+216),<(composite_data+224),<(composite_data+232),<(composite_data+240),<(composite_data+248),<(composite_data+256),<(composite_data+264),<(composite_data+272),<(composite_data+280),<(composite_data+288),<(composite_data+296),<(composite_data+304),<(composite_data+312),<(composite_data+320),<(composite_data+328),<(composite_data+336),<(composite_data+344),<(composite_data+352),<(composite_data+360),<(composite_data+368),<(composite_data+376),<(composite_data+384),<(composite_data+392),<(composite_data+400),<(composite_data+408),<(composite_data+416),<(composite_data+424),<(composite_data+432),<(composite_data+440),<(composite_data+448),<(composite_data+456),<(composite_data+464),<(composite_data+472),<(composite_data+480),<(composite_data+488),<(composite_data+496),<(composite_data+504),<(composite_data+512),<(composite_data+520),<(composite_data+528),<(composite_data+536),<(composite_data+544),<(composite_data+552),<(composite_data+560),<(composite_data+568),<(composite_data+576),<(composite_data+584),<(composite_data+592),<(composite_data+0)
.byte >(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+16),>(composite_data+24),>(composite_data+32),>(composite_data+40),>(composite_data+48),>(composite_data+56),>(composite_data+64),>(composite_data+72),>(composite_data+80),>(composite_data+88),>(composite_data+96),>(composite_data+104),>(composite_data+112),>(composite_data+120),>(composite_data+128),>(composite_data+136),>(composite_data+144),>(composite_data+152),>(composite_data+160),>(composite_data+168),>(composite_data+176),>(composite_data+184),>(composite_data+192),>(composite_data+200),>(composite_data+208),>(composite_data+216),>(composite_data+224),>(composite_data+232),>(composite_data+240),>(composite_data+248),>(composite_data+256),>(composite_data+264),>(composite_data+272),>(composite_data+280),>(composite_data+288),>(composite_data+296),>(composite_data+304),>(composite_data+312),>(composite_data+320),>(composite_data+328),>(composite_data+336),>(composite_data+344),>(composite_data+352),>(composite_data+360),>(composite_data+368),>(composite_data+376),>(composite_data+384),>(composite_data+392),>(composite_data+400),>(composite_data+408),>(composite_data+416),>(composite_data+424),>(composite_data+432),>(composite_data+440),>(composite_data+448),>(composite_data+456),>(composite_data+464),>(composite_data+472),>(composite_data+480),>(composite_data+488),>(composite_data+496),>(composite_data+504),>(composite_data+512),>(composite_data+520),>(composite_data+528),>(composite_data+536),>(composite_data+544),>(composite_data+552),>(composite_data+560),>(composite_data+568),>(composite_data+576),>(composite_data+584),>(composite_data+592),>(composite_data+0)
composite_row_1:
.byte <(composite_data+600),<(composite_data+0),<(composite_data+600),<(composite_data+0),<(composite_data+608),<(composite_data+8),<(composite_data+608),<(composite_data+8),<(composite_data+616),<(composite_data+624),<(composite_data+632),<(composite_data+640),<(composite_data+648),<(composite_data+656),<(composite_data+664),<(composite_data+672),<(composite_data+680),<(composite_data+688),<(composite_data+696),<(composite_data+704),<(composite_data+112),<(composite_data+712),<(composite_data+720),<(composite_data+728),<(composite_data+736),<(composite_data+744),<(composite_data+752),<(composite_data+760),<(composite_data+768),<(composite_data+776),<(composite_data+192),<(composite_data+784),<(composite_data+792),<(composite_data+800),<(composite_data+224),<(composite_data+808),<(composite_data+816),<(composite_data+824),<(composite_data+256),<(composite_data+832),<(composite_data+840),<(composite_data+848),<(composite_data+288),<(composite_data+296),<(composite_data+856),<(composite_data+864),<(composite_data+872),<(composite_data+880),<(composite_data+336),<(composite_data+888),<(composite_data+896),<(composite_data+904),<(composite_data+368),<(composite_data+912),<(composite_data+920),<(composite_data+928),<(composite_data+400),<(composite_data+936),<(composite_data+944),<(composite_data+424),<(composite_data+432),<(composite_data+952),<(composite_data+960),<(composite_data+456),<(composite_data+968),<(composite_data+976),<(composite_data+480),<(composite_data+984),<(composite_data+496),<(composite_data+992),<(composite_data+1000),<(composite_data+1008),<(composite_data+1016),<(composite_data+1024),<(composite_data+1032),<(composite_data+1040),<(composite_data+1048),<(composite_data+1056),<(composite_data+576),<(composite_data+1064),<(composite_data+1072),<(composite_data+600)
.byte >(composite_data+600),>(composite_data+0),>(composite_data+600),>(composite_data+0),>(composite_data+608),>(composite_data+8),>(composite_data+608),>(composite_data+8),>(composite_data+616),>(composite_data+624),>(composite_data+632),>(composite_data+640),>(composite_data+648),>(composite_data+656),>(composite_data+664),>(composite_data+672),>(composite_data+680),>(composite_data+688),>(composite_data+696),>(composite_data+704),>(composite_data+112),>(composite_data+712),>(composite_data+720),>(composite_data+728),>(composite_data+736),>(composite_data+744),>(composite_data+752),>(composite_data+760),>(composite_data+768),>(composite_data+776),>(composite_data+192),>(composite_data+784),>(composite_data+792),>(composite_data+800),>(composite_data+224),>(composite_data+808),>(composite_data+816),>(composite_data+824),>(composite_data+256),>(composite_data+832),>(composite_data+840),>(composite_data+848),>(composite_data+288),>(composite_data+296),>(composite_data+856),>(composite_data+864),>(composite_data+872),>(composite_data+880),>(composite_data+336),>(composite_data+888),>(composite_data+896),>(composite_data+904),>(composite_data+368),>(composite_data+912),>(composite_data+920),>(composite_data+928),>(composite_data+400),>(composite_data+936),>(composite_data+944),>(composite_data+424),>(composite_data+432),>(composite_data+952),>(composite_data+960),>(composite_data+456),>(composite_data+968),>(composite_data+976),>(composite_data+480),>(composite_data+984),>(composite_data+496),>(composite_data+992),>(composite_data+1000),>(composite_data+1008),>(composite_data+1016),>(composite_data+1024),>(composite_data+1032),>(composite_data+1040),>(composite_data+1048),>(composite_data+1056),>(composite_data+576),>(composite_data+1064),>(composite_data+1072),>(composite_data+600)
composite_row_2:
.byte <(composite_data+608),<(composite_data+8),<(composite_data+608),<(composite_data+8),<(composite_data+608),<(composite_data+8),<(composite_data+608),<(composite_data+8),<(composite_data+1080),<(composite_data+1088),<(composite_data+1096),<(composite_data+1104),<(composite_data+1112),<(composite_data+1120),<(composite_data+1128),<(composite_data+1136),<(composite_data+1144),<(composite_data+1152),<(composite_data+1160),<(composite_data+704),<(composite_data+1168),<(composite_data+1176),<(composite_data+1184),<(composite_data+728),<(composite_data+1192),<(composite_data+1200),<(composite_data+1208),<(composite_data+760),<(composite_data+1216),<(composite_data+1224),<(composite_data+1232),<(composite_data+1240),<(composite_data+1248),<(composite_data+1256),<(composite_data+1264),<(composite_data+1272),<(composite_data+1280),<(composite_data+1288),<(composite_data+1296),<(composite_data+1304),<(composite_data+1312),<(composite_data+1320),<(composite_data+1328),<(composite_data+1336),<(composite_data+1344),<(composite_data+1352),<(composite_data+1152),<(composite_data+1360),<(composite_data+1368),<(composite_data+1376),<(composite_data+1384),<(composite_data+1392),<(composite_data+1400),<(composite_data+1408),<(composite_data+1416),<(composite_data+1424),<(composite_data+1432),<(composite_data+936),<(composite_data+1440),<(composite_data+1448),<(composite_data+432),<(composite_data+1456),<(composite_data+1464),<(composite_data+456),<(composite_data+1472),<(composite_data+1480),<(composite_data+1488),<(composite_data+1496),<(composite_data+1504),<(composite_data+992),<(composite_data+1512),<(composite_data+1520),<(composite_data+1528),<(composite_data+1024),<(composite_data+1536),<(composite_data+1544),<(composite_data+1552),<(composite_data+1560),<(composite_data+576),<(composite_data+1064),<(composite_data+1568),<(composite_data+608)
.byte >(composite_data+608),>(composite_data+8),>(composite_data+608),>(composite_data+8),>(composite_data+608),>(composite_data+8),>(composite_data+608),>(composite_data+8),>(composite_data+1080),>(composite_data+1088),>(composite_data+1096),>(composite_data+1104),>(composite_data+1112),>(composite_data+1120),>(composite_data+1128),>(composite_data+1136),>(composite_data+1144),>(composite_data+1152),>(composite_data+1160),>(composite_data+704),>(composite_data+1168),>(composite_data+1176),>(composite_data+1184),>(composite_data+728),>(composite_data+1192),>(composite_data+1200),>(composite_data+1208),>(composite_data+760),>(composite_data+1216),>(composite_data+1224),>(composite_data+1232),>(composite_data+1240),>(composite_data+1248),>(composite_data+1256),>(composite_data+1264),>(composite_data+1272),>(composite_data+1280),>(composite_data+1288),>(composite_data+1296),>(composite_data+1304),>(composite_data+1312),>(composite_data+1320),>(composite_data+1328),>(composite_data+1336),>(composite_data+1344),>(composite_data+1352),>(composite_data+1152),>(composite_data+1360),>(composite_data+1368),>(composite_data+1376),>(composite_data+1384),>(composite_data+1392),>(composite_data+1400),>(composite_data+1408),>(composite_data+1416),>(composite_data+1424),>(composite_data+1432),>(composite_data+936),>(composite_data+1440),>(composite_data+1448),>(composite_data+432),>(composite_data+1456),>(composite_data+1464),>(composite_data+456),>(composite_data+1472),>(composite_data+1480),>(composite_data+1488),>(composite_data+1496),>(composite_data+1504),>(composite_data+992),>(composite_data+1512),>(composite_data+1520),>(composite_data+1528),>(composite_data+1024),>(composite_data+1536),>(composite_data+1544),>(composite_data+1552),>(composite_data+1560),>(composite_data+576),>(composite_data+1064),>(composite_data+1568),>(composite_data+608)
composite_row_3:
.byte <(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+1576),<(composite_data+1584),<(composite_data+1592),<(composite_data+1600),<(composite_data+1608),<(composite_data+1616),<(composite_data+1624),<(composite_data+1632),<(composite_data+1640),<(composite_data+1648),<(composite_data+1656),<(composite_data+104),<(composite_data+1168),<(composite_data+1664),<(composite_data+1672),<(composite_data+136),<(composite_data+1680),<(composite_data+1688),<(composite_data+1696),<(composite_data+168),<(composite_data+1704),<(composite_data+1712),<(composite_data+1232),<(composite_data+1720),<(composite_data+1728),<(composite_data+1736),<(composite_data+1264),<(composite_data+1744),<(composite_data+1752),<(composite_data+1760),<(composite_data+1296),<(composite_data+1768),<(composite_data+1776),<(composite_data+1784),<(composite_data+1328),<(composite_data+1336),<(composite_data+1792),<(composite_data+1800),<(composite_data+1648),<(composite_data+1808),<(composite_data+1368),<(composite_data+1816),<(composite_data+1824),<(composite_data+1832),<(composite_data+1400),<(composite_data+1840),<(composite_data+1848),<(composite_data+1856),<(composite_data+1432),<(composite_data+408),<(composite_data+1864),<(composite_data+1448),<(composite_data+432),<(composite_data+1872),<(composite_data+1880),<(composite_data+456),<(composite_data+1888),<(composite_data+1896),<(composite_data+1488),<(composite_data+1904),<(composite_data+1504),<(composite_data+504),<(composite_data+1912),<(composite_data+1920),<(composite_data+1928),<(composite_data+536),<(composite_data+1936),<(composite_data+1944),<(composite_data+1952),<(composite_data+1960),<(composite_data+576),<(composite_data+584),<(composite_data+1968),<(composite_data+8)
.byte >(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+1576),>(composite_data+1584),>(composite_data+1592),>(composite_data+1600),>(composite_data+1608),>(composite_data+1616),>(composite_data+1624),>(composite_data+1632),>(composite_data+1640),>(composite_data+1648),>(composite_data+1656),>(composite_data+104),>(composite_data+1168),>(composite_data+1664),>(composite_data+1672),>(composite_data+136),>(composite_data+1680),>(composite_data+1688),>(composite_data+1696),>(composite_data+168),>(composite_data+1704),>(composite_data+1712),>(composite_data+1232),>(composite_data+1720),>(composite_data+1728),>(composite_data+1736),>(composite_data+1264),>(composite_data+1744),>(composite_data+1752),>(composite_data+1760),>(composite_data+1296),>(composite_data+1768),>(composite_data+1776),>(composite_data+1784),>(composite_data+1328),>(composite_data+1336),>(composite_data+1792),>(composite_data+1800),>(composite_data+1648),>(composite_data+1808),>(composite_data+1368),>(composite_data+1816),>(composite_data+1824),>(composite_data+1832),>(composite_data+1400),>(composite_data+1840),>(composite_data+1848),>(composite_data+1856),>(composite_data+1432),>(composite_data+408),>(composite_data+1864),>(composite_data+1448),>(composite_data+432),>(composite_data+1872),>(composite_data+1880),>(composite_data+456),>(composite_data+1888),>(composite_data+1896),>(composite_data+1488),>(composite_data+1904),>(composite_data+1504),>(composite_data+504),>(composite_data+1912),>(composite_data+1920),>(composite_data+1928),>(composite_data+536),>(composite_data+1936),>(composite_data+1944),>(composite_data+1952),>(composite_data+1960),>(composite_data+576),>(composite_data+584),>(composite_data+1968),>(composite_data+8)
composite_row_4:
.byte <(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+16),<(composite_data+24),<(composite_data+32),<(composite_data+40),<(composite_data+48),<(composite_data+56),<(composite_data+64),<(composite_data+72),<(composite_data+80),<(composite_data+88),<(composite_data+1976),<(composite_data+1984),<(composite_data+328),<(composite_data+344),<(composite_data+384),<(composite_data+1992),<(composite_data+2000),<(composite_data+304),<(composite_data+2008),<(composite_data+320),<(composite_data+2016),<(composite_data+2024),<(composite_data+392),<(composite_data+2032),<(composite_data+160),<(composite_data+176),<(composite_data+2040),<(composite_data+2048),<(composite_data+2056),<(composite_data+512),<(composite_data+2064),<(composite_data+2072),<(composite_data+184),<(composite_data+2080),<(composite_data+200),<(composite_data+2088),<(composite_data+2096),<(composite_data+520),<(composite_data+2104),<(composite_data+2112),<(composite_data+2120),<(composite_data+2128),<(composite_data+2136),<(composite_data+2144),<(composite_data+2152),<(composite_data+2160),<(composite_data+2168),<(composite_data+2176),<(composite_data+2184),<(composite_data+2192),<(composite_data+2200),<(composite_data+2208),<(composite_data+2216),<(composite_data+2224),<(composite_data+2232),<(composite_data+2240),<(composite_data+2248),<(composite_data+2256),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0)
.byte >(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+16),>(composite_data+24),>(composite_data+32),>(composite_data+40),>(composite_data+48),>(composite_data+56),>(composite_data+64),>(composite_data+72),>(composite_data+80),>(composite_data+88),>(composite_data+1976),>(composite_data+1984),>(composite_data+328),>(composite_data+344),>(composite_data+384),>(composite_data+1992),>(composite_data+2000),>(composite_data+304),>(composite_data+2008),>(composite_data+320),>(composite_data+2016),>(composite_data+2024),>(composite_data+392),>(composite_data+2032),>(composite_data+160),>(composite_data+176),>(composite_data+2040),>(composite_data+2048),>(composite_data+2056),>(composite_data+512),>(composite_data+2064),>(composite_data+2072),>(composite_data+184),>(composite_data+2080),>(composite_data+200),>(composite_data+2088),>(composite_data+2096),>(composite_data+520),>(composite_data+2104),>(composite_data+2112),>(composite_data+2120),>(composite_data+2128),>(composite_data+2136),>(composite_data+2144),>(composite_data+2152),>(composite_data+2160),>(composite_data+2168),>(composite_data+2176),>(composite_data+2184),>(composite_data+2192),>(composite_data+2200),>(composite_data+2208),>(composite_data+2216),>(composite_data+2224),>(composite_data+2232),>(composite_data+2240),>(composite_data+2248),>(composite_data+2256),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0)
composite_row_5:
.byte <(composite_data+600),<(composite_data+0),<(composite_data+600),<(composite_data+0),<(composite_data+608),<(composite_data+8),<(composite_data+608),<(composite_data+8),<(composite_data+616),<(composite_data+624),<(composite_data+632),<(composite_data+640),<(composite_data+648),<(composite_data+656),<(composite_data+664),<(composite_data+672),<(composite_data+680),<(composite_data+688),<(composite_data+2264),<(composite_data+2272),<(composite_data+880),<(composite_data+888),<(composite_data+920),<(composite_data+2280),<(composite_data+2288),<(composite_data+856),<(composite_data+2296),<(composite_data+872),<(composite_data+2304),<(composite_data+2312),<(composite_data+928),<(composite_data+2032),<(composite_data+752),<(composite_data+768),<(composite_data+2320),<(composite_data+2328),<(composite_data+2336),<(composite_data+1000),<(composite_data+2344),<(composite_data+2352),<(composite_data+776),<(composite_data+2360),<(composite_data+784),<(composite_data+2368),<(composite_data+2096),<(composite_data+1008),<(composite_data+2376),<(composite_data+2384),<(composite_data+2392),<(composite_data+2400),<(composite_data+2408),<(composite_data+2416),<(composite_data+2424),<(composite_data+2432),<(composite_data+2168),<(composite_data+2440),<(composite_data+2448),<(composite_data+2456),<(composite_data+2464),<(composite_data+2472),<(composite_data+2480),<(composite_data+2488),<(composite_data+2496),<(composite_data+2504),<(composite_data+2248),<(composite_data+2512),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600)
.byte >(composite_data+600),>(composite_data+0),>(composite_data+600),>(composite_data+0),>(composite_data+608),>(composite_data+8),>(composite_data+608),>(composite_data+8),>(composite_data+616),>(composite_data+624),>(composite_data+632),>(composite_data+640),>(composite_data+648),>(composite_data+656),>(composite_data+664),>(composite_data+672),>(composite_data+680),>(composite_data+688),>(composite_data+2264),>(composite_data+2272),>(composite_data+880),>(composite_data+888),>(composite_data+920),>(composite_data+2280),>(composite_data+2288),>(composite_data+856),>(composite_data+2296),>(composite_data+872),>(composite_data+2304),>(composite_data+2312),>(composite_data+928),>(composite_data+2032),>(composite_data+752),>(composite_data+768),>(composite_data+2320),>(composite_data+2328),>(composite_data+2336),>(composite_data+1000),>(composite_data+2344),>(composite_data+2352),>(composite_data+776),>(composite_data+2360),>(composite_data+784),>(composite_data+2368),>(composite_data+2096),>(composite_data+1008),>(composite_data+2376),>(composite_data+2384),>(composite_data+2392),>(composite_data+2400),>(composite_data+2408),>(composite_data+2416),>(composite_data+2424),>(composite_data+2432),>(composite_data+2168),>(composite_data+2440),>(composite_data+2448),>(composite_data+2456),>(composite_data+2464),>(composite_data+2472),>(composite_data+2480),>(composite_data+2488),>(composite_data+2496),>(composite_data+2504),>(composite_data+2248),>(composite_data+2512),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600)
composite_row_6:
.byte <(composite_data+608),<(composite_data+8),<(composite_data+608),<(composite_data+8),<(composite_data+608),<(composite_data+8),<(composite_data+608),<(composite_data+8),<(composite_data+1080),<(composite_data+1088),<(composite_data+1096),<(composite_data+1104),<(composite_data+1112),<(composite_data+1120),<(composite_data+1128),<(composite_data+1136),<(composite_data+1144),<(composite_data+1152),<(composite_data+2520),<(composite_data+2528),<(composite_data+1360),<(composite_data+1376),<(composite_data+1416),<(composite_data+2280),<(composite_data+2536),<(composite_data+1344),<(composite_data+2544),<(composite_data+1152),<(composite_data+2552),<(composite_data+2560),<(composite_data+1424),<(composite_data+2568),<(composite_data+1208),<(composite_data+1216),<(composite_data+2576),<(composite_data+2584),<(composite_data+2592),<(composite_data+1512),<(composite_data+2600),<(composite_data+2608),<(composite_data+1224),<(composite_data+2616),<(composite_data+1240),<(composite_data+2624),<(composite_data+2632),<(composite_data+1520),<(composite_data+2640),<(composite_data+2648),<(composite_data+2656),<(composite_data+2400),<(composite_data+2664),<(composite_data+2672),<(composite_data+2680),<(composite_data+1136),<(composite_data+2688),<(composite_data+2696),<(composite_data+2704),<(composite_data+2712),<(composite_data+2720),<(composite_data+2472),<(composite_data+2728),<(composite_data+2736),<(composite_data+2744),<(composite_data+2752),<(composite_data+2760),<(composite_data+2768),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608)
.byte >(composite_data+608),>(composite_data+8),>(composite_data+608),>(composite_data+8),>(composite_data+608),>(composite_data+8),>(composite_data+608),>(composite_data+8),>(composite_data+1080),>(composite_data+1088),>(composite_data+1096),>(composite_data+1104),>(composite_data+1112),>(composite_data+1120),>(composite_data+1128),>(composite_data+1136),>(composite_data+1144),>(composite_data+1152),>(composite_data+2520),>(composite_data+2528),>(composite_data+1360),>(composite_data+1376),>(composite_data+1416),>(composite_data+2280),>(composite_data+2536),>(composite_data+1344),>(composite_data+2544),>(composite_data+1152),>(composite_data+2552),>(composite_data+2560),>(composite_data+1424),>(composite_data+2568),>(composite_data+1208),>(composite_data+1216),>(composite_data+2576),>(composite_data+2584),>(composite_data+2592),>(composite_data+1512),>(composite_data+2600),>(composite_data+2608),>(composite_data+1224),>(composite_data+2616),>(composite_data+1240),>(composite_data+2624),>(composite_data+2632),>(composite_data+1520),>(composite_data+2640),>(composite_data+2648),>(composite_data+2656),>(composite_data+2400),>(composite_data+2664),>(composite_data+2672),>(composite_data+2680),>(composite_data+1136),>(composite_data+2688),>(composite_data+2696),>(composite_data+2704),>(composite_data+2712),>(composite_data+2720),>(composite_data+2472),>(composite_data+2728),>(composite_data+2736),>(composite_data+2744),>(composite_data+2752),>(composite_data+2760),>(composite_data+2768),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608)
composite_row_7:
.byte <(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+1576),<(composite_data+1584),<(composite_data+1592),<(composite_data+1600),<(composite_data+1608),<(composite_data+1616),<(composite_data+1624),<(composite_data+1632),<(composite_data+1640),<(composite_data+1648),<(composite_data+2776),<(composite_data+2784),<(composite_data+1808),<(composite_data+1816),<(composite_data+1848),<(composite_data+1992),<(composite_data+2792),<(composite_data+1792),<(composite_data+2800),<(composite_data+1648),<(composite_data+2808),<(composite_data+2816),<(composite_data+1856),<(composite_data+2568),<(composite_data+1696),<(composite_data+1704),<(composite_data+2824),<(composite_data+2832),<(composite_data+2840),<(composite_data+1912),<(composite_data+2848),<(composite_data+2856),<(composite_data+1712),<(composite_data+2864),<(composite_data+1720),<(composite_data+2872),<(composite_data+2632),<(composite_data+1920),<(composite_data+2880),<(composite_data+2888),<(composite_data+2896),<(composite_data+2128),<(composite_data+2904),<(composite_data+2912),<(composite_data+2920),<(composite_data+1632),<(composite_data+2688),<(composite_data+2928),<(composite_data+2936),<(composite_data+2944),<(composite_data+2952),<(composite_data+2208),<(composite_data+2960),<(composite_data+2968),<(composite_data+2976),<(composite_data+2984),<(composite_data+2760),<(composite_data+2992),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8)
.byte >(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+1576),>(composite_data+1584),>(composite_data+1592),>(composite_data+1600),>(composite_data+1608),>(composite_data+1616),>(composite_data+1624),>(composite_data+1632),>(composite_data+1640),>(composite_data+1648),>(composite_data+2776),>(composite_data+2784),>(composite_data+1808),>(composite_data+1816),>(composite_data+1848),>(composite_data+1992),>(composite_data+2792),>(composite_data+1792),>(composite_data+2800),>(composite_data+1648),>(composite_data+2808),>(composite_data+2816),>(composite_data+1856),>(composite_data+2568),>(composite_data+1696),>(composite_data+1704),>(composite_data+2824),>(composite_data+2832),>(composite_data+2840),>(composite_data+1912),>(composite_data+2848),>(composite_data+2856),>(composite_data+1712),>(composite_data+2864),>(composite_data+1720),>(composite_data+2872),>(composite_data+2632),>(composite_data+1920),>(composite_data+2880),>(composite_data+2888),>(composite_data+2896),>(composite_data+2128),>(composite_data+2904),>(composite_data+2912),>(composite_data+2920),>(composite_data+1632),>(composite_data+2688),>(composite_data+2928),>(composite_data+2936),>(composite_data+2944),>(composite_data+2952),>(composite_data+2208),>(composite_data+2960),>(composite_data+2968),>(composite_data+2976),>(composite_data+2984),>(composite_data+2760),>(composite_data+2992),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8)
composite_row_8:
.byte <(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+16),<(composite_data+24),<(composite_data+32),<(composite_data+40),<(composite_data+48),<(composite_data+56),<(composite_data+64),<(composite_data+72),<(composite_data+80),<(composite_data+88),<(composite_data+3000),<(composite_data+3008),<(composite_data+3016),<(composite_data+3024),<(composite_data+3032),<(composite_data+3040),<(composite_data+3048),<(composite_data+3056),<(composite_data+2144),<(composite_data+3064),<(composite_data+2160),<(composite_data+3072),<(composite_data+3080),<(composite_data+3088),<(composite_data+3096),<(composite_data+3104),<(composite_data+3112),<(composite_data+3120),<(composite_data+3128),<(composite_data+3136),<(composite_data+3144),<(composite_data+3152),<(composite_data+3160),<(composite_data+3168),<(composite_data+2216),<(composite_data+3176),<(composite_data+2232),<(composite_data+3184),<(composite_data+3192),<(composite_data+3200),<(composite_data+3208),<(composite_data+3216),<(composite_data+2136),<(composite_data+3224),<(composite_data+3232),<(composite_data+384),<(composite_data+3240),<(composite_data+3248),<(composite_data+304),<(composite_data+3256),<(composite_data+320),<(composite_data+3264),<(composite_data+392),<(composite_data+3272),<(composite_data+3280),<(composite_data+3288),<(composite_data+3296),<(composite_data+2240),<(composite_data+3304),<(composite_data+3312),<(composite_data+512),<(composite_data+184),<(composite_data+3320),<(composite_data+200),<(composite_data+3328),<(composite_data+3336),<(composite_data+3344),<(composite_data+520),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0),<(composite_data+0)
.byte >(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+16),>(composite_data+24),>(composite_data+32),>(composite_data+40),>(composite_data+48),>(composite_data+56),>(composite_data+64),>(composite_data+72),>(composite_data+80),>(composite_data+88),>(composite_data+3000),>(composite_data+3008),>(composite_data+3016),>(composite_data+3024),>(composite_data+3032),>(composite_data+3040),>(composite_data+3048),>(composite_data+3056),>(composite_data+2144),>(composite_data+3064),>(composite_data+2160),>(composite_data+3072),>(composite_data+3080),>(composite_data+3088),>(composite_data+3096),>(composite_data+3104),>(composite_data+3112),>(composite_data+3120),>(composite_data+3128),>(composite_data+3136),>(composite_data+3144),>(composite_data+3152),>(composite_data+3160),>(composite_data+3168),>(composite_data+2216),>(composite_data+3176),>(composite_data+2232),>(composite_data+3184),>(composite_data+3192),>(composite_data+3200),>(composite_data+3208),>(composite_data+3216),>(composite_data+2136),>(composite_data+3224),>(composite_data+3232),>(composite_data+384),>(composite_data+3240),>(composite_data+3248),>(composite_data+304),>(composite_data+3256),>(composite_data+320),>(composite_data+3264),>(composite_data+392),>(composite_data+3272),>(composite_data+3280),>(composite_data+3288),>(composite_data+3296),>(composite_data+2240),>(composite_data+3304),>(composite_data+3312),>(composite_data+512),>(composite_data+184),>(composite_data+3320),>(composite_data+200),>(composite_data+3328),>(composite_data+3336),>(composite_data+3344),>(composite_data+520),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0),>(composite_data+0)
composite_row_9:
.byte <(composite_data+600),<(composite_data+0),<(composite_data+600),<(composite_data+0),<(composite_data+608),<(composite_data+8),<(composite_data+608),<(composite_data+8),<(composite_data+616),<(composite_data+624),<(composite_data+632),<(composite_data+640),<(composite_data+648),<(composite_data+656),<(composite_data+664),<(composite_data+672),<(composite_data+680),<(composite_data+688),<(composite_data+3352),<(composite_data+3360),<(composite_data+3368),<(composite_data+3376),<(composite_data+3384),<(composite_data+3392),<(composite_data+3400),<(composite_data+3408),<(composite_data+2416),<(composite_data+3416),<(composite_data+2432),<(composite_data+3424),<(composite_data+3432),<(composite_data+3440),<(composite_data+3448),<(composite_data+3456),<(composite_data+3464),<(composite_data+3472),<(composite_data+3480),<(composite_data+3488),<(composite_data+3496),<(composite_data+3504),<(composite_data+3512),<(composite_data+3520),<(composite_data+2480),<(composite_data+3528),<(composite_data+2496),<(composite_data+3536),<(composite_data+3544),<(composite_data+3552),<(composite_data+3208),<(composite_data+3560),<(composite_data+2408),<(composite_data+3568),<(composite_data+3576),<(composite_data+920),<(composite_data+3584),<(composite_data+3592),<(composite_data+856),<(composite_data+3600),<(composite_data+872),<(composite_data+3608),<(composite_data+928),<(composite_data+3272),<(composite_data+3616),<(composite_data+3624),<(composite_data+3632),<(composite_data+2504),<(composite_data+3640),<(composite_data+3648),<(composite_data+1000),<(composite_data+776),<(composite_data+3656),<(composite_data+784),<(composite_data+3664),<(composite_data+3672),<(composite_data+3680),<(composite_data+1008),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600),<(composite_data+600)
.byte >(composite_data+600),>(composite_data+0),>(composite_data+600),>(composite_data+0),>(composite_data+608),>(composite_data+8),>(composite_data+608),>(composite_data+8),>(composite_data+616),>(composite_data+624),>(composite_data+632),>(composite_data+640),>(composite_data+648),>(composite_data+656),>(composite_data+664),>(composite_data+672),>(composite_data+680),>(composite_data+688),>(composite_data+3352),>(composite_data+3360),>(composite_data+3368),>(composite_data+3376),>(composite_data+3384),>(composite_data+3392),>(composite_data+3400),>(composite_data+3408),>(composite_data+2416),>(composite_data+3416),>(composite_data+2432),>(composite_data+3424),>(composite_data+3432),>(composite_data+3440),>(composite_data+3448),>(composite_data+3456),>(composite_data+3464),>(composite_data+3472),>(composite_data+3480),>(composite_data+3488),>(composite_data+3496),>(composite_data+3504),>(composite_data+3512),>(composite_data+3520),>(composite_data+2480),>(composite_data+3528),>(composite_data+2496),>(composite_data+3536),>(composite_data+3544),>(composite_data+3552),>(composite_data+3208),>(composite_data+3560),>(composite_data+2408),>(composite_data+3568),>(composite_data+3576),>(composite_data+920),>(composite_data+3584),>(composite_data+3592),>(composite_data+856),>(composite_data+3600),>(composite_data+872),>(composite_data+3608),>(composite_data+928),>(composite_data+3272),>(composite_data+3616),>(composite_data+3624),>(composite_data+3632),>(composite_data+2504),>(composite_data+3640),>(composite_data+3648),>(composite_data+1000),>(composite_data+776),>(composite_data+3656),>(composite_data+784),>(composite_data+3664),>(composite_data+3672),>(composite_data+3680),>(composite_data+1008),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600),>(composite_data+600)
composite_row_10:
.byte <(composite_data+608),<(composite_data+8),<(composite_data+608),<(composite_data+8),<(composite_data+608),<(composite_data+8),<(composite_data+608),<(composite_data+8),<(composite_data+1080),<(composite_data+1088),<(composite_data+1096),<(composite_data+1104),<(composite_data+1112),<(composite_data+1120),<(composite_data+1128),<(composite_data+1136),<(composite_data+1144),<(composite_data+1152),<(composite_data+3688),<(composite_data+3696),<(composite_data+3704),<(composite_data+3712),<(composite_data+3720),<(composite_data+3728),<(composite_data+3736),<(composite_data+3744),<(composite_data+2672),<(composite_data+3752),<(composite_data+1136),<(composite_data+3760),<(composite_data+3768),<(composite_data+3776),<(composite_data+3784),<(composite_data+3792),<(composite_data+3800),<(composite_data+3808),<(composite_data+3816),<(composite_data+3824),<(composite_data+3832),<(composite_data+3840),<(composite_data+3848),<(composite_data+3856),<(composite_data+2728),<(composite_data+3864),<(composite_data+2744),<(composite_data+3872),<(composite_data+3880),<(composite_data+3888),<(composite_data+3896),<(composite_data+3904),<(composite_data+2664),<(composite_data+3912),<(composite_data+3920),<(composite_data+1416),<(composite_data+3928),<(composite_data+3936),<(composite_data+1344),<(composite_data+3944),<(composite_data+1152),<(composite_data+3952),<(composite_data+1424),<(composite_data+3960),<(composite_data+3968),<(composite_data+3976),<(composite_data+3984),<(composite_data+2752),<(composite_data+3992),<(composite_data+3648),<(composite_data+1512),<(composite_data+1224),<(composite_data+4000),<(composite_data+1240),<(composite_data+4008),<(composite_data+4016),<(composite_data+4024),<(composite_data+1520),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608),<(composite_data+608)
.byte >(composite_data+608),>(composite_data+8),>(composite_data+608),>(composite_data+8),>(composite_data+608),>(composite_data+8),>(composite_data+608),>(composite_data+8),>(composite_data+1080),>(composite_data+1088),>(composite_data+1096),>(composite_data+1104),>(composite_data+1112),>(composite_data+1120),>(composite_data+1128),>(composite_data+1136),>(composite_data+1144),>(composite_data+1152),>(composite_data+3688),>(composite_data+3696),>(composite_data+3704),>(composite_data+3712),>(composite_data+3720),>(composite_data+3728),>(composite_data+3736),>(composite_data+3744),>(composite_data+2672),>(composite_data+3752),>(composite_data+1136),>(composite_data+3760),>(composite_data+3768),>(composite_data+3776),>(composite_data+3784),>(composite_data+3792),>(composite_data+3800),>(composite_data+3808),>(composite_data+3816),>(composite_data+3824),>(composite_data+3832),>(composite_data+3840),>(composite_data+3848),>(composite_data+3856),>(composite_data+2728),>(composite_data+3864),>(composite_data+2744),>(composite_data+3872),>(composite_data+3880),>(composite_data+3888),>(composite_data+3896),>(composite_data+3904),>(composite_data+2664),>(composite_data+3912),>(composite_data+3920),>(composite_data+1416),>(composite_data+3928),>(composite_data+3936),>(composite_data+1344),>(composite_data+3944),>(composite_data+1152),>(composite_data+3952),>(composite_data+1424),>(composite_data+3960),>(composite_data+3968),>(composite_data+3976),>(composite_data+3984),>(composite_data+2752),>(composite_data+3992),>(composite_data+3648),>(composite_data+1512),>(composite_data+1224),>(composite_data+4000),>(composite_data+1240),>(composite_data+4008),>(composite_data+4016),>(composite_data+4024),>(composite_data+1520),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608),>(composite_data+608)
composite_row_11:
.byte <(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+1576),<(composite_data+1584),<(composite_data+1592),<(composite_data+1600),<(composite_data+1608),<(composite_data+1616),<(composite_data+1624),<(composite_data+1632),<(composite_data+1640),<(composite_data+1648),<(composite_data+4032),<(composite_data+4040),<(composite_data+4048),<(composite_data+4056),<(composite_data+4064),<(composite_data+4072),<(composite_data+4080),<(composite_data+4088),<(composite_data+2912),<(composite_data+4096),<(composite_data+1632),<(composite_data+4104),<(composite_data+4112),<(composite_data+4120),<(composite_data+4128),<(composite_data+4136),<(composite_data+4144),<(composite_data+4152),<(composite_data+4160),<(composite_data+4168),<(composite_data+4176),<(composite_data+4184),<(composite_data+4192),<(composite_data+4200),<(composite_data+2960),<(composite_data+4208),<(composite_data+2976),<(composite_data+4216),<(composite_data+4224),<(composite_data+4232),<(composite_data+3896),<(composite_data+4240),<(composite_data+2904),<(composite_data+4248),<(composite_data+4256),<(composite_data+1848),<(composite_data+4264),<(composite_data+4272),<(composite_data+1792),<(composite_data+4280),<(composite_data+1648),<(composite_data+4288),<(composite_data+1856),<(composite_data+3960),<(composite_data+4296),<(composite_data+4304),<(composite_data+4312),<(composite_data+2984),<(composite_data+4320),<(composite_data+3312),<(composite_data+1912),<(composite_data+1712),<(composite_data+4328),<(composite_data+1720),<(composite_data+4336),<(composite_data+4344),<(composite_data+4352),<(composite_data+1920),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8),<(composite_data+8)
.byte >(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+1576),>(composite_data+1584),>(composite_data+1592),>(composite_data+1600),>(composite_data+1608),>(composite_data+1616),>(composite_data+1624),>(composite_data+1632),>(composite_data+1640),>(composite_data+1648),>(composite_data+4032),>(composite_data+4040),>(composite_data+4048),>(composite_data+4056),>(composite_data+4064),>(composite_data+4072),>(composite_data+4080),>(composite_data+4088),>(composite_data+2912),>(composite_data+4096),>(composite_data+1632),>(composite_data+4104),>(composite_data+4112),>(composite_data+4120),>(composite_data+4128),>(composite_data+4136),>(composite_data+4144),>(composite_data+4152),>(composite_data+4160),>(composite_data+4168),>(composite_data+4176),>(composite_data+4184),>(composite_data+4192),>(composite_data+4200),>(composite_data+2960),>(composite_data+4208),>(composite_data+2976),>(composite_data+4216),>(composite_data+4224),>(composite_data+4232),>(composite_data+3896),>(composite_data+4240),>(composite_data+2904),>(composite_data+4248),>(composite_data+4256),>(composite_data+1848),>(composite_data+4264),>(composite_data+4272),>(composite_data+1792),>(composite_data+4280),>(composite_data+1648),>(composite_data+4288),>(composite_data+1856),>(composite_data+3960),>(composite_data+4296),>(composite_data+4304),>(composite_data+4312),>(composite_data+2984),>(composite_data+4320),>(composite_data+3312),>(composite_data+1912),>(composite_data+1712),>(composite_data+4328),>(composite_data+1720),>(composite_data+4336),>(composite_data+4344),>(composite_data+4352),>(composite_data+1920),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8),>(composite_data+8)
composite_row_lo:
.byte <composite_row_0,<composite_row_1,<composite_row_2,<composite_row_3,<composite_row_4,<composite_row_5,<composite_row_6,<composite_row_7,<composite_row_8,<composite_row_9,<composite_row_10,<composite_row_11
composite_row_hi:
.byte >composite_row_0,>composite_row_1,>composite_row_2,>composite_row_3,>composite_row_4,>composite_row_5,>composite_row_6,>composite_row_7,>composite_row_8,>composite_row_9,>composite_row_10,>composite_row_11
composite_class:
.byte 0,0,1,0,2,3,2,3
.segment "CODE"
STATIC_COUNT=18
static_merge_0:
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 rts
static_merge_1:
 lda (rp_shape),y
 ora #85
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #85
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #85
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 rts
static_merge_2:
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 rts
static_merge_3:
 lda (rp_shape),y
 ora #85
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #85
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #85
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 rts
static_merge_4:
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 rts
static_merge_5:
 lda (rp_shape),y
 ora #85
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #85
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #85
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 rts
static_merge_6:
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 rts
static_merge_7:
 lda (rp_shape),y
 ora #85
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #85
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #85
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #80
 sta (rp_dst),y
 rts
static_merge_8:
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #2
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #2
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #2
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #2
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #2
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #2
 sta (rp_dst),y
 rts
static_merge_9:
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #170
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #170
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #170
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #170
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #170
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #170
 sta (rp_dst),y
 rts
static_merge_10:
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #168
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #168
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #168
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #168
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #168
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #168
 sta (rp_dst),y
 rts
static_merge_11:
 lda (rp_shape),y
 ora #2
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #2
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #2
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #2
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #2
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #2
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #2
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #2
 sta (rp_dst),y
 rts
static_merge_12:
 lda (rp_shape),y
 ora #170
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #170
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #170
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #170
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #170
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #170
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #170
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #170
 sta (rp_dst),y
 rts
static_merge_13:
 lda (rp_shape),y
 ora #168
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #168
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #168
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #168
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #168
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #168
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #168
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #168
 sta (rp_dst),y
 rts
static_merge_14:
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #42
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #42
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #10
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #10
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #10
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #10
 sta (rp_dst),y
 rts
static_merge_15:
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #128
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #128
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 rts
static_merge_16:
 lda (rp_shape),y
 ora #10
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #10
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #10
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #10
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #10
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #10
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #42
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #42
 sta (rp_dst),y
 rts
static_merge_17:
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #128
 sta (rp_dst),y
 iny
 lda (rp_shape),y
 ora #128
 sta (rp_dst),y
 rts
.segment "RODATA"
static_merge_lo:
.byte <static_merge_0,<static_merge_1,<static_merge_2,<static_merge_3,<static_merge_4,<static_merge_5,<static_merge_6,<static_merge_7,<static_merge_8,<static_merge_9,<static_merge_10,<static_merge_11,<static_merge_12,<static_merge_13,<static_merge_14,<static_merge_15,<static_merge_16,<static_merge_17
static_merge_hi:
.byte >static_merge_0,>static_merge_1,>static_merge_2,>static_merge_3,>static_merge_4,>static_merge_5,>static_merge_6,>static_merge_7,>static_merge_8,>static_merge_9,>static_merge_10,>static_merge_11,>static_merge_12,>static_merge_13,>static_merge_14,>static_merge_15,>static_merge_16,>static_merge_17
.segment "CODE"
