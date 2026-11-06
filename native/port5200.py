"""Build-time 5200 platform adaptation of the preserved XL generator output."""
from pathlib import Path
import re
p=Path('native/5200');p.mkdir(exist_ok=True)
for f in ('platform','assets','hud_generated','terrain','objects','contacts','audio','entropy','select','fixed_renderer'):
 s=Path('native/'+f+'.s').read_text()
 s=re.sub(r'\$d0([0-9a-f]{2})',r'$c0\1',s)
 s=re.sub(r'\$d2([0-9a-f]{2})',r'$e8\1',s)
 # Fixed RAM workspaces. Hardware at D4xx remains unchanged.
 def addr(m):
  v=int(m[1],16)
  for lo,hi,new in [(0x8000,0x8400,0x1400),(0x9000,0x9c00,0x2000),(0x9f18,0x9f68,0x1770),(0xa000,0xa400,0xc00),(0xa800,0xac00,0x1000),(0xb000,0xb168,0x500),(0xb300,0xb400,0x700),(0xc800,0xd000,0x1800),(0xe400,0xe800,0x2c00)]:
   if lo<=v<hi:return '$%04x'%(new+v-lo)
  return m[0]
 # Skip obsolete loader: it will be replaced below.
 if f=='platform':
  st=s.index('start:');en=s.index('main_loop:',st)
  s=s[:st]+Path('native/start5200.s').read_text()+s[en:]
  st=s.index('read_input:');en=s.index('make_display_list:',st)
  s=s[:st]+'.include "input5200.s"\n'+s[en:]
  s=s.replace('.include "display_demo.s"','')
  s=s.replace(' jsr _game_tick', ' lda paused\n bne frame_complete\n jsr _game_tick')
  # The 5200 BIOS dispatches VBI and DLI separately and preserves A.
  st=s.index('nmi:\n');en=s.index('dli_middle:',st)
  s=s[:st]+'''nmi:
 pha
 sta $d40f
 lda _mode
 beq @title
 lda display_ready
 beq @done
 ; Always restore the mine charset at the real vertical blank. Do not
 ; depend on the previous frame having delivered every display-list NMI.
 jsr frame_palette
 jmp @done
@title:
 inc frame_number
 bne @select_ready
 inc frame_number+1
@select_ready:
 lda #0
 sta pending
@done:
 pla
 rti
dli_entry:
 pha
 ; Route from the beam position, not a self-modifying chain that can drift
 ; permanently when a scene rebuild interrupts the old display list.
 lda $d40b
 cmp #80
 bcs :+
 jmp dli_middle
: cmp #104
 bcs :+
 jmp dli_bottom
: cmp #116
 bcs :+
 jmp dli_hud
: jmp vbi_begin
'''+s[en:]
  s=re.sub(r' lda #<[a-z_]+\n sta dli_dispatch\+1\n lda #>[a-z_]+\n sta dli_dispatch\+2\n','',s)
  # Stop display NMIs before rewriting shared display data. SEI alone does
  # not mask NMI. Both title and gameplay setups re-enable after completion.
  s=s.replace('scene_setup:\n','scene_setup:\n lda #0\n sta $d40e\n sta display_ready\n sta pending\n')
  s=s.replace(' lda #$3e\n sta $d400\n rts',' lda #$3e\n sta $d400\n lda #0\n sta $d40f\n lda #$c0\n sta $d40e\n rts')

  # The separator above the score must not fetch character glyphs while
  # CHBASE changes. Preserve its 3-pixel floor, then use real blank lines;
  # switch to the HUD font two scanlines before the HUD character DMA.
  old_separator='dlrow21:\n.byte 196,72,23'
  assert old_separator in s
  s=s.replace(old_separator,'''dlrow21:
.byte $4e,<bottom_row,>bottom_row
.byte $4e,<bottom_row,>bottom_row
.byte $4e,<bottom_row,>bottom_row
.byte $a0,$10''')
  # Font table contains 82 static glyphs; the 45 mutable ones are cleared in RAM.
  st=s.index('static_font:');en=s.index('rock_tile_codes:',st)
  vals=[int(v) for v in re.findall(r'\d+',s[st+len('static_font:'):en])]
  assert len(vals)==3072
  packed=b''.join(bytes(vals[i:i+656]) for i in (0,1024,2048))
  s=s[:st]+'static_font:\n'+''.join('.byte '+','.join(map(str,packed[i:i+16]))+'\n' for i in range(0,len(packed),16))+s[en:]
  s=s.replace(' .repeat 12,P\n lda static_font+P*256,x\n sta FONT+P*256,x\n .endrepeat',' .repeat 12,P\n sta FONT+P*256,x\n .endrepeat')
  s=s.replace(': lda #$0f\n ldx #40',': jsr copy_fonts\n lda #$0f\n ldx #40')
  s += '''\ncopy_fonts:
 ldx #0
@pages:
 .repeat 3,P
 lda static_font+P*656,x
 sta FONT+P*1024,x
 lda static_font+P*656+256,x
 sta FONT+P*1024+256,x
 .endrepeat
 inx
 bne @pages
 ldx #0
@tail:
 .repeat 3,P
 lda static_font+P*656+512,x
 sta FONT+P*1024+512,x
 .endrepeat
 inx
 cpx #144
 bne @tail
 lda #$55
 ldx #7
@solid:
 .repeat 3,P
 sta FONT+P*1024+1016,x
 .endrepeat
 dex
 bpl @solid
 rts
'''
 if f=='select':
  s=s.replace('select_setup:\n','select_setup:\n lda #0\n sta $d40e\n')
  s=s.replace(' lda #$3e\n sta $d400\n rts',' lda #$3e\n sta $d400\n lda #0\n sta $d40f\n lda #$c0\n sta $d40e\n rts')
 if f=='assets':
  st=s.index('.export letter_shapes');en=s.index('.segment "RODATA"',st)
  s=s[:st]+s[en:]
 if f=='hud_generated':
  s=s.replace('.segment "EXTRA"\n.align 1024\nhud_font:', '.segment "HUDFONT"\nhud_font:')
  s=s.replace('hud_name_glyphs:', '.segment "EXTRA"\nhud_name_glyphs:')
  s=re.sub(r'\.assert hud_.*\n','',s)
  st=s.index('hud_name_lo:');en=s.index('.segment "BSS"',st)
  s=s[:st]+'hud_name_lo:\n.byte '+','.join('<(hud_name_glyphs+%d)'%(i*32) for i in range(64))+'\nhud_name_hi:\n.byte '+','.join('>(hud_name_glyphs+%d)'%(i*32) for i in range(64))+'\n'+s[en:]
  # Only glyph IDs 0..45 are accepted by the name-entry rules.
  st=s.index('hud_name_glyphs:');en=s.index('hud_digit_codes:',st)
  vals=[int(v) for v in re.findall(r'\d+',s[st+len('hud_name_glyphs:'):en])][:46*32]
  s=s[:st]+'hud_name_glyphs:\n'+''.join('.byte '+','.join(map(str,vals[i:i+16]))+'\n' for i in range(0,len(vals),16))+s[en:]
 if f=='fixed_renderer':
  # Commit can repeat while paused. Reset the self-modifying destination on
  # EVERY commit; leaving it at the previous batch's last page corrupts the
  # next character bank when more than 32 cells were copied.
  patch=''' lda font_page
 clc
 adc #2
 .repeat 8,R
 sta .ident(.sprintf("font_store_%d",R))+2
 .endrepeat
'''
  assert s.count(patch)==1
  s=s.replace(patch,'')
  s=s.replace('rocks_commit:\n','rocks_commit:\n'+patch)
  s=s.replace('adc #8\n sta rp_bg+1','adc #4\n sta rp_bg+1')
  s=s.replace('sbc #$20\n sta $22','sbc #$f8\n sta $22')
  s=s.replace('adc #$28\n sta $24','adc #$fc\n sta $24')
  s=s.replace('static_call:\n jsr static_merge_0\n jmp composite_done',' jmp static_call\n.segment "RAMCODE"\nstatic_call:\n jsr static_merge_0\n jmp composite_done\n.segment "CODE"')
  s=s.replace('font_copy_loop:\n',' jmp font_copy_loop\n.segment "RAMCODE"\nfont_copy_loop:\n')
  s=s.replace(' beq font_copy_maps\n txa',' bne :+\n jmp font_copy_maps\n: txa')
  s=s.replace('font_copy_maps:\n','.segment "CODE"\nfont_copy_maps:\n')
 if f=='audio':
  s='.import key_age,latched_key\n.export audio_noise_running\n'+s
  s=s.replace(' sta $e80e',' sta $e80e')
  s=s.replace(' lda #0\n sta $e80e', ' lda #$40\n sta $e80e\n lda #0')
  s=s.replace(' lda #2\n sta $e80e', ' lda #$42\n sta $e80e')
  s=s.replace(' sta $e807\n sta $e80e', ' sta $e807\n lda #$40\n sta $e80e')
  s=s.replace('audio_irq:\n pha', '.segment "RAMCODE"\naudio_irq:\n pha\n lda $e80e\n and #$40\n bne @timer\n lda $e809\n and #$1e\n sta latched_key\n lda #3\n sta key_age\n lda audio_noise_running\n asl a\n sta $e80e\n ora #$40\n sta $e80e\n pla\n rti\n@timer:')
 s=re.sub(r'\$([0-9a-f]{4})(?![0-9a-f])',addr,s)
 s=s.replace('#$c8\n sta $d407','#$18\n sta $d407')
 s=s.replace('#$e4','# $2c'.replace(' ',''))
 if f=='fixed_renderer':s=s.replace('#$90','#$20')
 s=s.replace('.import letter_shapes,', '.import')
 p.joinpath(f+'.s').write_text(s)
