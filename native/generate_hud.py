"""ANTIC 4 score band: static digit glyphs, 36 fixed name glyphs, one map."""
from pathlib import Path
import re
raw=Path('reference/o2em-cset.c').read_text().split('uint8_t cset[512]= {')[1].split('}')[0]
f=bytes(int(x,16) for x in re.findall(r'0x([a-fA-F0-9]+)',raw))
u=[bytes(8),bytes([0x50]*8)]
def tiles(ch,ink):
 b=bytearray(48)
 for dy in range(14):
  for px in range(8):
   if f[ch*8+dy//2]&(128>>px):
    x=1+px;y=dy;b[(y//8*3+x//4)*8+(y&7)]|=ink<<(6-2*(x&3))
 return [bytes(b[i:i+8]) for i in range(0,48,8)]
def code(t):
 if t not in u:u.append(t)
 return u.index(t)
digits=[code(t) for ink in (2,3) for ch in range(10) for t in tiles(ch,ink)]
tails=[code(t) for ch in range(64) for t in tiles(ch,3)[2::3]]
arrow=[code(t) for t in tiles(54,2)]
name_base=len(u)
assert name_base+24<=128
names=b''.join(t for ch in range(64) for i,t in enumerate(tiles(ch,3)) if i%3<2)
# Actual load bytes appended after the terrain tables in EXTRA.
a=[];w=a.append
w('.import _score_changed,_name_changed,_name_chars,_score,_high_score,hud_shadow\n.export prepare_hud,commit_hud,hud_scene\nsrc=$30\ntemp=$3e\nglyph=$42')
w('.segment "EXTRA"\n.align 1024\nhud_font:')
def data(b):
 for i in range(0,len(b),16):w('.byte '+','.join(str(x) for x in b[i:i+16]))
data(b''.join(u).ljust(1024,b'\0'))
w('hud_name_glyphs:');data(names)
w('hud_digit_codes:');data(digits)
w('hud_tail_codes:');data(tails)
w('.assert hud_font=$e400, lderror, "HUD font address"\n.assert hud_name_glyphs=$e800, lderror, "HUD name address"\n.segment "RODATA"\nhud_name_lo:');data([(0xe800+ch*32)&255 for ch in range(64)])
w('hud_name_hi:');data([(0xe800+ch*32)>>8 for ch in range(64)])
w('.segment "BSS"\nhud_dirty:.res 14\nhud_ready:.res 84\nhud_name_src_lo:.res 6\nhud_name_src_hi:.res 6\n.segment "CODE"')
w('''hud_scene:
 ldx #39
 lda #0
@clear:
 sta $9f18,x
 sta $9f40,x
 dex
 bpl @clear
 lda #1
 sta $9f1a
 sta $9f3e
 sta $9f42
 sta $9f66
''')
for row in range(2):
 for col in range(2):w(f' lda #{arrow[row*3+col]}\n sta ${0x9f18+row*40+12+col:04x}')
w(''' lda #$e4
 sta $d409
 rts
prepare_hud:
 lda _score_changed
 ora _name_changed
 bne :+
 rts
: lda #0
 sta _score_changed
 sta _name_changed
 ldx #0
@field:
 cpx #4
 bcc @high
 cpx #8
 bcc @score
 lda _name_chars-8,x
 jmp @check
@score:
 lda _score-4,x
 jmp @check
@high:
 lda _high_score,x
@check:
 cmp hud_shadow,x
 bne :+
 jmp @next
: sta hud_shadow,x
 cpx #8
 bcs @name
 asl a
 sta temp
 asl a
 clc
 adc temp
 cpx #4
 bcc :+
 clc
 adc #60
: clc
 adc #<hud_digit_codes
 sta src
 lda #>hud_digit_codes
 adc #0
 sta src+1
''')
for k in range(6):w(f' ldy #{k}\n lda (src),y\n sta hud_ready+{k*14},x')
w(f' jmp @dirty\n@name:\n tay\n lda hud_name_lo,y\n sta hud_name_src_lo-8,x\n lda hud_name_hi,y\n sta hud_name_src_hi-8,x\n tya\n asl a\n tay\n txa\n sec\n sbc #8\n asl a\n asl a\n clc\n adc #{name_base}\n sta glyph')
for row in range(2):
 for col in range(2):w(f' lda glyph\n sta hud_ready+{(row*3+col)*14},x\n inc glyph')
 w(f' lda hud_tail_codes+{row},y\n sta hud_ready+{(row*3+2)*14},x')
w('''@dirty:
 lda #1
 sta hud_dirty,x
 cpx #8
 bcc @next
 cpx #13
 bcs @next
 sta hud_dirty+1,x
@next:
 inx
 cpx #14
 beq :+
 jmp @field
: rts
commit_hud:''')
xs=[17,25,33,41,113,121,129,137,57,65,73,81,89,97]
for k,x in enumerate(xs):
 w(f' lda hud_dirty+{k}\n bne :+\n jmp hud_done{k}\n: lda #0\n sta hud_dirty+{k}')
 if k>=8:
  n=k-8;w(f' lda hud_name_src_lo+{n}\n sta $21\n lda hud_name_src_hi+{n}\n sta $22\n ldy #31\n@copy{k}:\n lda ($21),y\n sta ${0xe400+name_base*8+n*32:04x},y\n dey\n bpl @copy{k}')
  if k>8:
   for row in range(2):
    w(f' lda hud_ready+{(row*3+2)*14+k-1}\n asl a\n asl a\n asl a\n sta $21\n lda hud_ready+{(row*3+2)*14+k-1}\n lsr a\n lsr a\n lsr a\n lsr a\n lsr a\n clc\n adc #$e4\n sta $22\n ldy #7\n@merge{k}_{row}:\n lda ($21),y\n ora ${0xe400+name_base*8+n*32+row*16:04x},y\n sta ${0xe400+name_base*8+n*32+row*16:04x},y\n dey\n bpl @merge{k}_{row}')

 for row in range(2):
  for col in range(3):
   # Digit glyphs have an empty last pixel; preserve the adjacent arrow.
   if k==3 and col==2:continue
   w(f' lda hud_ready+{(row*3+col)*14+k}\n sta ${0x9f18+row*40+x//4+col:04x}')
 w(f'hud_done{k}:')
w(' rts\n.segment "CODE"')
source='\n'.join(a)+'\n'
start=source.index('prepare_hud:');end=source.index('@field:',start)
fast=['prepare_hud:', ' lda _score_changed', ' bne :+', ' jmp @names_only', ': lda #0', ' sta _score_changed']
for k in range(8):
 field=('_high_score+'+str(k)) if k<4 else ('_score+'+str(k-4))
 fast += [f' lda {field}',f' cmp hud_shadow+{k}',' beq :+',f' sta hud_shadow+{k}',' asl a',' sta temp',' asl a',' clc',' adc temp']
 if k>=4:fast+=[' clc',' adc #60']
 fast+=[' tax']
 for part in range(6):fast += [f' lda hud_digit_codes+{part},x',f' sta hud_ready+{part*14+k}']
 fast+=[' lda #1',f' sta hud_dirty+{k}',':']
fast+=['@names_only:',' lda _name_changed',' bne :+',' rts',': lda #0',' sta _name_changed',' ldx #8']
source=source[:start]+'\n'.join(fast)+'\n'+source[end:]
Path('native/hud_generated.s').write_text(source)
