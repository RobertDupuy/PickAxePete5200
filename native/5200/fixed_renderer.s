; Dedicated five-boulder ANTIC 4 renderer. Foreground scratch $49-$5f.
; One visible charset; STAGE contains at most 45 working glyphs (360 bytes).
rp_base=$36
rp_map=$49
rp_bg=$4b
rp_shape=$4d
rp_dst=$4f
rp_src=$51
rp_obj=$53
rp_x=$54
rp_y=$55
rp_col=$56
rp_row=$57
rp_index=$58
rp_frame=$59
rp_top=$5a
rp_num=$5b
rp_tmp=$5c
rp_slot=$5d
rp_codes=$5e
rp_record=$60
rp_cell=$61
.segment "CODE"
prepare_effects:
 ldx #2
@one:
 lda #0
 ldy _door_open,x
 beq :+
 lda _frame
 and #4
 beq :+
 lda #6
: sta ready_door,x
 dex
 bpl @one
 ; Fixed door patches in the background map, included in any rock composite.
 .repeat 3,D
 ldx ready_door+D
 .repeat 6,C
 lda door_codes+C,x
 sta BACKMAP+(19-9*D)*40+19+(C/3)*40+(C .mod 3)
 .endrepeat
 .endrepeat
 rts

rocks_prepare:
 lda #0
 .repeat 8,Q
 .if Q<4
 sta active_rows+4+Q+(Q/2)
 .else
 sta active_rows+13+(Q-4)+((Q-4)/2)
 .endif
 .endrepeat
 ldx #4
clear_cells:
 lda base_lo,x
 sta old_base_lo,x
 sta rp_map
 lda base_hi,x
 sta old_base_hi,x
 beq clear_next
 sta rp_map+1
 lda #0
 .repeat 9,C
 ldy #(C/3)*40+(C .mod 3)
 sta (rp_map),y
 .endrepeat
clear_next:
 lda #0
 sta base_hi,x
 dex
 bpl clear_cells
 lda #0
 .repeat 45,C
 sta cell_code+C
 .endrepeat
rocks_start:
 lda #0
 sta cell_count
 sta work_count
 sta rp_obj
 sta rp_frame
 lda #$88
 sta rock_color
 lda _frame
 and #3
 bne @rock
 lda #32
 sta rp_frame
 lda _frame
 and #16
 beq :+
 lda #64
 sta rp_frame
: lda #$68
 sta rock_color
@rock:
 lda rp_frame
 lsr a
 lsr a
 lsr a
 clc
 adc #$20
 sta font_page
 ldx rp_obj
 lda _rock_y,x
 and #254
 cmp #24
 bcs :+
 jmp @next
:
 cmp #210
 bcc :+
 jmp @next
:
 sec
 sbc #24
 sta rp_y
 and #7
 asl a
 asl a
 clc
 adc rp_frame
 sta rp_index
 lda _rock_x,x
 clc
 adc #2
 cmp #151
 bcc :+
 jmp @next
:
 sta rp_x
 and #3
 clc
 adc rp_index
 tay
 lda shift_lo,y
 sta rp_codes
 lda shift_hi,y
 sta rp_codes+1
 lda rp_x
 lsr a
 lsr a
 sta rp_x
 lda rp_y
 lsr a
 lsr a
 lsr a
 sta rp_y
 tax
 lda map_row_lo,x
 clc
 adc rp_x
 sta rp_base
 ldy rp_obj
 sta base_lo,y
 lda map_row_hi,x
 adc #0
 sta rp_base+1
 sta base_hi,y
 tya
 asl a
 asl a
 asl a
 clc
 adc rp_obj
 sta rp_record
 .repeat 9,C
 ldy #C
 lda (rp_codes),y
 beq :+
 sta rp_top
 ldx rp_y
 lda #1
 sta active_rows+C/3,x
 lda rp_record
 clc
 adc #C
 sta rp_cell
 lda rp_base
 clc
 adc #(C/3)*40+(C .mod 3)
 sta rp_map
 sta rp_bg
 lda rp_base+1
 adc #0
 sta rp_map+1
 clc
 adc #4
 sta rp_bg+1
 jsr rock_cell
:
 .endrepeat
@next:
 inc rp_obj
 lda rp_obj
 cmp #5
 beq :+
 jmp @rock
: lda work_count
 cmp #32
 bcc @short
 lda #32
@short:
 asl a
 asl a
 asl a
 sta copy_slots
 lda #0
 sta copy_tail
 lda work_count
 cmp #33
 bcc @copy_pointers
 sec
 sbc #32
 asl a
 asl a
 asl a
 sta copy_tail
@copy_pointers:
 rts

rock_cell:
 ldy #0
 lda (rp_map),y
 bne rc_background
 lda (rp_bg),y
 bne :+
 jmp rc_plain
:
rc_background:
 cmp #8
 bcs :+
 jmp precomputed_static
:
 sta rp_num
 cmp #STATIC_COUNT
 bcc rc_composite
 cmp #82
 bcc rc_static
 sec
 sbc #82
 tax
 lda work_src_lo,x
 sta rp_src
 lda work_src_hi,x
 sta rp_src+1
 jmp rc_composite
rc_static:
 tax
 lda glyph_lo,x
 sta rp_src
 lda glyph_hi,x
 sec
 sbc #$20
 clc
 adc font_page
 sta rp_src+1
rc_composite:
 ldx work_count
 lda stage_lo,x
 sta rp_dst
 sta work_src_lo,x
 lda stage_hi,x
 sta rp_dst+1
 sta work_src_hi,x
 inc work_count
 txa
 clc
 adc #82
 sta rp_slot
 ldx rp_top
 lda glyph_lo,x
 sta rp_shape
 lda glyph_hi,x
 clc
 adc font_page
 sec
 sbc #$20
 sta rp_shape+1
 ldx rp_num
 cpx #STATIC_COUNT
 bcs rc_dynamic
 lda static_merge_lo,x
 sta static_call+1
 lda static_merge_hi,x
 sta static_call+2
 jmp static_call
.segment "RAMCODE"
static_call:
 jsr static_merge_0
 jmp composite_done
.segment "CODE"
rc_dynamic:
 .repeat 8,R
 .if R>0
 iny
 .endif
 lda (rp_src),y
 ora (rp_shape),y
 sta (rp_dst),y
 .endrepeat
composite_done:
 lda rp_slot
 bne rc_emit
rc_plain:
 lda rp_top
rc_emit:
 ldy #0
 sta (rp_map),y
 ldx rp_cell
 sta cell_code,x
 inc cell_count
 rts

precomputed_static:
 tax
 lda font_page
 sec
 sbc #$20
 clc
 adc composite_class,x
 tax
 lda composite_row_lo,x
 sta rp_src
 lda composite_row_hi,x
 sta rp_src+1
 ldx work_count
 inc work_count
 ldy rp_top
 lda (rp_src),y
 sta work_src_lo,x
 clc
 lda rp_src
 adc #82
 sta rp_src
 bcc :+
 inc rp_src+1
: lda (rp_src),y
 sta work_src_hi,x
 txa
 clc
 adc #82
 jmp rc_emit

next_patch:
 clc
 lda rp_dst
 adc #5
 sta rp_dst
 bcc :+
 inc rp_dst+1
: rts

rocks_commit:
 lda font_page
 clc
 adc #2
 .repeat 8,R
 sta .ident(.sprintf("font_store_%d",R))+2
 .endrepeat
 .repeat 8,Q
 .if Q<4
 R .set 4+Q+(Q/2)
 .else
 R .set 13+(Q-4)+((Q-4)/2)
 .endif
 lda active_rows+R
 beq :+
 lda #$44
 sta DLIST+4+R*3
 lda #<(SCREEN+R*40)
 sta DLIST+5+R*3
 lda #>(SCREEN+R*40)
 bne :++
: lda #$50
 sta DLIST+4+R*3
 lda #0
 sta DLIST+5+R*3
: sta DLIST+6+R*3
 .endrepeat
 lda work_count
 beq font_copy_maps
 lda #0
 sta $25
 ldx #0
 jmp font_copy_loop
.segment "RAMCODE"
font_copy_loop:
 ldy $25
 lda work_src_lo,y
 sta $21
 lda work_src_hi,y
 sta $22
 .repeat 8,R
 ldy #R
 lda ($21),y
.ident(.sprintf("font_store_%d",R)):
 sta FONT+82*8+R,x
 .endrepeat
 inc $25
 lda $25
 cmp work_count
 bne :+
 jmp font_copy_maps
: txa
 clc
 adc #8
 tax
 bne font_copy_loop
 .repeat 8,R
 inc .ident(.sprintf("font_store_%d",R))+2
 .endrepeat
 jmp font_copy_loop
.segment "CODE"
font_copy_maps:
 .repeat 5,P
 lda old_base_hi+P
 beq :+
 sec
 sbc #$f8
 sta $22
 clc
 adc #$fc
 sta $24
 lda old_base_lo+P
 sta $21
 sta $23
 .repeat 9,C
 ldy #(C/3)*40+(C .mod 3)
 lda ($23),y
 sta ($21),y
 .endrepeat
:
 .endrepeat
 .repeat 3,D
 .repeat 6,C
 lda BACKMAP+(19-9*D)*40+19+(C/3)*40+(C .mod 3)
 sta SCREEN+(19-9*D)*40+19+(C/3)*40+(C .mod 3)
 .endrepeat
 .endrepeat
 .repeat 5,P
 .scope
 lda base_hi+P
 bne :+
 jmp player_done
:
 sec
 sbc #$f8
 sta $22
 lda base_lo+P
 sta $21
 .repeat 9,C
 lda cell_code+P*9+C
 beq :+
 ldy #(C/3)*40+(C .mod 3)
 sta ($21),y
 :
 .endrepeat
player_done:
 .endscope
 .endrepeat
 rts

pm_prepare:
 ldx #3
@one:
 lda #0
 sta pm_width,x
 lda #16
 sta pm_height,x
 lda pm_y,x
 cmp #219
 bcc :+
 lda #0
 sta pm_height,x
: dex
 bpl @one
 lda _effect_size
 beq @done
 lda pm_height+3
 beq @done
 lda #32
 sta pm_height+3
 lda #1
 sta pm_width+3
@done:rts

; NMI-only scratch. Ordinary Y moves overwrite the old tail with padding.
iptr=$21
iy=$23
ilen=$24
pm_commit:
 .repeat 4,P
 .scope
 lda pm_y+P
 cmp pm_old_y+P
 bne :+
 lda pm_height+P
 cmp pm_old_height+P
 bne :+
 lda pm_dirty+P
 bne :+
 jmp pm_position_P
: lda pm_y+P
 sec
 sbc pm_old_y+P
 clc
 adc #4
 cmp #9
 bcs pm_clear_P
pm_same_y_P:
 lda pm_height+P
 cmp pm_old_height+P
 beq pm_draw_P
pm_clear_P:
 ldx pm_old_height+P
 beq pm_draw_P
 lda pm_old_y+P
 clc
 adc #16
 tay
 lda #0
pm_clear_loop_P:
 sta PMBASE+$400+P*256,y
 iny
 beq pm_draw_P
 dex
 bne pm_clear_loop_P
pm_draw_P:
 lda #1
 sta ilen
 jmp pm_state_P
pm_position_P:
 lda #0
 sta ilen
pm_state_P:
 lda pm_y+P
 sta pm_old_y+P
 lda pm_height+P
 sta pm_old_height+P
 bne pm_visible_P
 lda #0
 sta $c000+P
 jmp pm_done_P
pm_visible_P:
 lda pm_x+P
 clc
 adc #50
 sta $c000+P
 lda pm_color+P
 sta $c012+P
 lda pm_width+P
 sta $c008+P
 lda ilen
 bne :+
 jmp pm_done_P
: lda pm_y+P
 clc
 adc #12
 tay
 lda #0
 .repeat 4,B
 sta PMBASE+$400+P*256,y
 iny
 .endrepeat
 .if P=3
 lda pm_width+P
 bne :+
 jmp pm_normal_P
:
 .repeat 8,R
 lda pm_pattern+P*8+R
 .repeat 4,B
 sta PMBASE+$400+P*256,y
 iny
 bne :+
 jmp pm_done_P
 :
 .endrepeat
 .endrepeat
 jmp pm_tail_P
pm_normal_P:
 .endif
 .repeat 8,R
 lda pm_pattern+P*8+R
 sta PMBASE+$400+P*256,y
 iny
 sta PMBASE+$400+P*256,y
 iny
 .endrepeat
pm_tail_P:
 lda #0
 .repeat 4,B
 sta PMBASE+$400+P*256,y
 iny
 .endrepeat
pm_done_P:
 .endscope
 .endrepeat
 rts
.segment "RODATA"
pm_offsets:.byte 0,40,80,120
.segment "CODE"

transition_commit:
 lda transition_live
 beq :+
 jmp @paint
:
 inc transition_live
 .repeat 21,R
 lda #$44
 .if R=9 .or R=18
 ora #$80
 .endif
 sta DLIST+4+R*3
 lda #<$0700
 sta DLIST+5+R*3
 lda #>$0700
 sta DLIST+6+R*3
 .endrepeat
@paint:
 ldx #39
 lda #0
@clear:
 sta $0700,x
 dex
 bpl @clear
 ldx _transition_stage
 lda wipe_starts,x
 tay
 lda wipe_counts,x
 tax
 lda #127
@bar:
 sta $0700,y
 iny
 dex
 bne @bar
 rts
.segment "RODATA"
wipe_starts:.byte 2,6,10,14,18
wipe_counts:.byte 36,28,20,12,4
.segment "CODE"
