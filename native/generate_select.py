"""Original BIOS SELECT GAME glyphs, spacing and seven simultaneous colors."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
bios = (root / 'reference/o2rom.bin').read_bytes()
text = bios[0x2f2:0x2fd]
assert list(text) == [25, 18, 14, 18, 35, 20, 12, 28, 32, 38, 18]
raw = (root / 'reference/o2em-cset.c').read_text().split('uint8_t cset[512]= {')[1].split('}')[0]
font = bytes(int(x, 16) for x in re.findall(r'0x([a-fA-F0-9]+)', raw))
bitmap = bytearray(14 * 40)
for i in (0, 1, 2, 8, 9, 10):
    ink = i % 8 + 1
    for y in range(14):
        for x in range(8):
            if font[text[i] * 8 + y // 2] & (128 >> x):
                px = 42 + i * 8 + x
                bitmap[y * 40 + px // 4] |= ink << (6 - 2 * (px & 3))

a = ['; Generated from Odyssey2 BIOS $2f2-$2fc and the original character ROM.',
     '.import _scene_changed', '.export select_setup', '.segment "EXTRA"']
def data(name, values):
    a.append(name + ':')
    for i in range(0, len(values), 16):
        a.append('.byte ' + ','.join(str(v) for v in values[i:i + 16]))
data('select_bitmap', bitmap)
for p, i in enumerate((3, 4, 5, 7)):
    data('select_player' + str(p), [font[text[i] * 8 + y // 2] for y in range(14)])
a += ['select_dlist:', '.byte ' + ','.join(['$70'] * 15),
      '.byte $4e,<select_bitmap,>select_bitmap',
      '.byte ' + ','.join(['$0e'] * 13),
      '.byte $41,<$0400,>$0400', 'select_dlist_end:', '.segment "CODE"',
      '''select_setup:
 lda #0
 sta $d400
 sta _scene_changed
 sta $d01a
 ldx #0
@clear:
 .repeat 8,P
 sta $c800+P*256,x
 .endrepeat
 inx
 bne @clear
 ldx #select_dlist_end-select_dlist-1
@list:
 lda select_dlist,x
 sta $0400,x
 dex
 bpl @list
 lda #<$0400
 sta $d402
 lda #>$0400
 sta $d403
 lda #$c8
 sta $d407
 lda #3
 sta $d01d
 lda #1
 sta $d01b
 lda #0
 .repeat 4,P
 sta $d008+P
 .endrepeat
 ldx #13
@players:
 .repeat 4,P
 lda .ident(.sprintf("select_player%d",P)),x
 sta $cc80+P*256,x
 .endrepeat
 dex
 bpl @players
 lda #114
 sta $d000
 lda #122
 sta $d001
 lda #130
 sta $d002
 lda #146
 sta $d003
 lda #$6e
 sta $d012
 lda #$ac
 sta $d013
 lda #$0e
 sta $d014
 lda #$4a
 sta $d015
 lda #$cc
 sta $d016
 lda #$2c
 sta $d017
 lda #$9c
 sta $d018
 lda #$3e
 sta $d400
 rts
''']
(root / 'native/select.s').write_text('\n'.join(a))
