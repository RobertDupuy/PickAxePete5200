"""Dedicated character display: build-time shifts, fixed glyph workspace."""
from pathlib import Path
import re
p=Path('native')
old=(p/'display_source.s').read_text()
a=[]
def w(s):a.append(s)
def data(name,values):
 w(name+':')
 for i in range(0,len(values),16):w('.byte '+','.join(str(v) for v in values[i:i+16]))
w(old[:old.index('; Interrupt scratch')].replace('.import screen_row_lo, screen_row_hi, background_row_lo, background_row_hi\n',''))
w('''src=$30
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
''')
w(old[old.index('read_input:'):old.index('make_display_list:')])
w('''make_display_list:
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
''')
sprites=old[old.index('prepare_sprites:'):old.index('nmi:')]
sprites=sprites.replace(' ldy #7\n@pete:\n lda (src),y\n sta pm_pattern,y\n dey\n bpl @pete',' .repeat 8,R\n ldy #R\n lda (src),y\n sta pm_pattern+R\n .endrepeat')
for label,source,offset in [('ladder','ladder_shapes',8),('pick','pick_shapes',16),('loose_bytes','loose_shapes',16),('effect_bytes','effect_shapes',24)]:
 before=f' ldy #0\n@{label}:\n lda {source},x\n sta pm_pattern+{offset},y\n inx\n iny\n cpy #8\n bne @{label}'
 after=f' .repeat 8,R\n lda {source}+R,x\n sta pm_pattern+{offset}+R\n .endrepeat'
 sprites=sprites.replace(before,after)
sprites=sprites.replace(" beq @loose", " bne :+\n jmp @loose\n:")
sprites=sprites.replace('prepare_sprites:', 'prepare_sprites:\n lda #0\n sta pm_dirty\n sta pm_dirty+1\n sta pm_dirty+3\n lda #1\n sta pm_dirty+2')
sprites=sprites.replace(' lda _pete_shape\n asl a', ' lda _pete_shape\n cmp last_pete_shape\n beq @pete_copied\n sta last_pete_shape\n inc pm_dirty\n asl a')
sprites=sprites.replace(' lda _ladder_x', '@pete_copied:\n lda _ladder_x')
sprites=sprites.replace(' lda _ladder_shape\n asl a', ' lda _ladder_shape\n cmp last_ladder_shape\n beq @ladder_copied\n sta last_ladder_shape\n inc pm_dirty+1\n asl a')
sprites=sprites.replace(' lda #$68\n sta pm_color+2', '@ladder_copied:\n lda #$68\n sta pm_color+2')
sprites=sprites.replace(' lda _effect_shape\n and #1\n asl a', ' lda _effect_shape\n and #1\n cmp last_effect_shape\n beq @doors\n sta last_effect_shape\n inc pm_dirty+3\n asl a')
sprites=sprites.replace(' ldy #7\n@mask:\n ldx _item_mask,y\n lda reverse_bits,x\n and pm_pattern+16,y\n sta pm_pattern+16,y\n dey\n bpl @mask',' .repeat 8,R\n ldx _item_mask+R\n lda reverse_bits,x\n and pm_pattern+16+R\n sta pm_pattern+16+R\n .endrepeat')
sprites=sprites.replace("sta live_door_colors,x","sta ready_door_colors,x")
w(sprites)
w('''.include "fixed_renderer.s"
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
''')
# Source y24 begins at physical line40. Fixed palette splits only, no PM mux.
for r in range(24):
 addr=0x1400+r*40
 if r in (22,23):addr=0x1770+(r-22)*40
 instr=0x44|(0x80 if r in (9,18,21) else 0)
 data('dlrow'+str(r),[instr,addr&255,addr>>8])
w('.byte $4e,<bottom_row,>bottom_row,$4e,<bottom_row,>bottom_row,$ce,<bottom_row,>bottom_row,$41,<DLIST,>DLIST\nfixed_dlist_end:')
data('bottom_row',[0,0]+[0x55]*36+[0x50,0])
w(old[old.index('keymap:'):old.index('.include "effects.s"')])
raw=Path('reference/o2em-cset.c').read_text().split('uint8_t cset[512]= {')[1].split('}')[0]
font=bytes(int(x,16) for x in re.findall(r'0x([a-fA-F0-9]+)',raw))
stat=[bytes([0]*8), bytes([0x55]*3+[0]*5),bytes([0x50]*3+[0]*5),bytes([0x55]*3+[0]*5)]
# Bits 0/1 = horizontal/full/partial; bit 2 = vertical two-pixel wall.
stat += [bytes(b|0x50 for b in v) for v in stat]
def tile(img,r,c):return bytes(sum(int(img[r*8+y][c*4+x])<<(6-2*x) for x in range(4)) for y in range(8))
doors=[]
for opened in (0,1):
 img=[[0]*12 for _ in range(16)]
 for y in range(14):
  for x in range(8):
   # Bank 0 $6c8-$6d3 selects original characters $2f (closed) / $16 (open).
   on=font[(22 if opened else 47)*8+y//2] & (128>>x)
   if on:img[y+2][x+3]=2
 doors.append([])
 for r in range(2):
  for c in range(3):
   v=tile(img,r,c)
   if v not in stat:stat.append(v)
   doors[-1].append(stat.index(v))
assert len(stat)<64
base=bytearray(1024)
for r in range(25):base[r*40+2]=base[r*40+38]=4
for c in range(2,38):base[24*40+c]|=1
base[24*40+38]|=2
for r in (1,10,19):
 for rr in range(2):
  for c in range(3):base[(r+rr)*40+19+c]=doors[0][rr*3+c]
data('base_map',list(base))

data('door_codes',sum(doors,[]))
data('map_row_lo',[(0x0c00+y*40)&255 for y in range(25)])
data('map_row_hi',[(0x0c00+y*40)>>8 for y in range(25)])
data('glyph_lo',[(0x2000+i*8)&255 for i in range(128)])
data('glyph_hi',[(0x2000+i*8)>>8 for i in range(128)])
data('stage_lo',[(0x0500+i*8)&255 for i in range(45)])
data('stage_hi',[(0x0500+i*8)>>8 for i in range(45)])
rocks=[font[49*8+1:49*8+7]+bytes([0]),font[16*8:16*8+7],font[41*8:41*8+7]]
fonts=[];codes=[]
for fr in range(3):
 bank=list(stat);bc=[]
 for sy in range(8):
  for sx in range(4):
   img=[[0]*12 for _ in range(24)]
   for y in range(14):
    for x in range(8):
     if rocks[fr][y//2]&(128>>x):img[(sy&6)+y][sx+x]=3
   for r in range(3):
    for c in range(3):
     t=tile(img,r,c)
     if t not in bank:bank.append(t)
     bc.append(bank.index(t))
 assert len(bank)<=82, len(bank)
 fonts.append(b''.join(bank).ljust(1016,b'\0')+bytes([0x55]*8));codes+=bc
print('Static glyph counts:',[len(set(f[i:i+8] for i in range(0,640,8))) for f in fonts])
data('static_font',list(b''.join(fonts)))

data('rock_tile_codes',codes)
labels=['rock_tile_codes+'+str(fr*288+sy*36+sx*9) for fr in range(3) for sy in range(8) for sx in range(4)]
w('shift_lo:\n.byte '+','.join('<('+x+')' for x in labels))
w('shift_hi:\n.byte '+','.join('>('+x+')' for x in labels))
# Precompose rock/scenery pairs once. Empty cells already use static glyphs.
composites=[];lookup=[]
for f in fonts:
 for bg in (1,2,4,5):
  row=[]
  for c in range(82):
   t=bytes(a|b for a,b in zip(stat[bg],f[c*8:c*8+8]))
   if t not in composites:composites.append(t)
   row.append(composites.index(t))
  lookup.append(row)
data('composite_data',list(b''.join(composites)))
for n,row in enumerate(lookup):
 w('composite_row_'+str(n)+':')
 w('.byte '+','.join('<(composite_data+'+str(i*8)+')' for i in row))
 w('.byte '+','.join('>(composite_data+'+str(i*8)+')' for i in row))
w('composite_row_lo:\n.byte '+','.join('<composite_row_'+str(i) for i in range(12)))
w('composite_row_hi:\n.byte '+','.join('>composite_row_'+str(i) for i in range(12)))
data('composite_class',[0,0,1,0,2,3,2,3])
w('.segment "CODE"')
w('STATIC_COUNT='+str(len(stat)))
for n,t in enumerate(stat):
 w('static_merge_'+str(n)+':')
 for y,v in enumerate(t):
  if y:w(' iny')
  w(' lda (rp_shape),y')
  if v:w(' ora #'+str(v))
  w(' sta (rp_dst),y')
 w(' rts')
w('.segment "RODATA"')
w('static_merge_lo:\n.byte '+','.join('<static_merge_'+str(n) for n in range(len(stat))))
w('static_merge_hi:\n.byte '+','.join('>static_merge_'+str(n) for n in range(len(stat))))
w('.segment "CODE"')
(p/'platform.s').write_text('\n'.join(a)+'\n')
