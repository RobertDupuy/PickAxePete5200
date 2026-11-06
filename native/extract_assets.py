"""Extract artwork and mine data once, at build time. Never translate code.

The executable contains named assets, not a mapped source ROM. Addresses here
are provenance only; the game engine does not know the source machine.
"""
from pathlib import Path
import re,json
root=Path(__file__).resolve().parents[1]
cart=(root/'reference/pickaxe.bin').read_bytes()
b0=bytes(1024)+cart[2048:];b1=bytes(1024)+cart[:2048]
raw=(root/'reference/o2em-cset.c').read_text().split('uint8_t cset[512]= {')[1].split('}')[0]
font=bytes(int(x,16) for x in re.findall(r'0x([a-fA-F0-9]+)',raw))
rev=lambda x:int(f'{x:08b}'[::-1],2)
frames=[(1,x) for x in [0xb2c,0xb34,0xb3c,0xb44,0xb4c,0xb54,0xb5c,0xb64,
 0xb6c,0xb74,0xb7c,0xb84,0xb8c,0xb94,0xb9c,0xba4,0xbac,0xbb4,
 0xbbc,0xbc4,0xbcc,0xbd4,0xbdc,0xbe4,0xbec,0xbf4]]
frames += [(0,x) for x in [0xb7f,0xb87,0xb8f,0xb97,0xb9f,0xba7]]
frames += [(1,x) for x in [0x7bd,0x7c5,0x7cd,0x7d5,0x7dd]]
out=['/* Generated from original artwork and layout data; see extract_assets.py. */']
def carray(n,b):
 out.append('const byte '+n+'['+str(len(b))+'] = {')
 for i in range(0,len(b),18):out.append(' '+','.join(str(x) for x in b[i:i+18])+',')
 out.append('};')
carray('mine_layouts',b1[0x6a3:0x6fd])
(root/'native/assets.h').write_text('\n'.join(out)+'\n')
asm=['; Extracted original artwork. Normal MSB-left bitmaps.','.segment "RODATA"']
def data(n,b,export=True):
 if export:asm.append('.export '+n)
 asm.append(n+':')
 for i in range(0,len(b),16):asm.append('.byte '+','.join(f'${x:02x}' for x in b[i:i+16]))
data('pete_shapes',bytes(rev(v) for bank,a in frames for v in (b0,b1)[bank][a:a+8]))
data('ladder_shapes',bytes(rev(v) for a in (0xb0c,0xb14,0xb1c,0xb24) for v in b1[a:a+8]))
data('pick_shapes',bytes(rev(v) for a in (0xbaf,0xbb7,0xbbf,0xbc7) for v in b0[a:a+8]))
data('loose_shapes',bytes(rev(v) for a in (0x596,0x59e,0x5a6,0x5ae,0x5b6,0x5be,0x5c6,0x5ce) for v in b1[a:a+8]))
data('effect_shapes',bytes(rev(v) for a in (0xabb,0xac3) for v in b1[a:a+8]))
data('death_shapes',bytes(rev(v) for a in (0x7bd,0x7c5,0x7cd,0x7d5,0x7dd) for v in b1[a:a+8]))
asm.append('.segment "AUX"')
data('letter_shapes',font)
asm.append('.segment "RODATA"')
# Four rolling rock frames from the source character ROM. 14 scan lines.
# Character 49 is drawn two scan lines above the nominal position.
rocks=[font[49*8+1:49*8+7]+bytes([0]),font[16*8:16*8+7],font[41*8:41*8+7]]
data('_rock_glyphs',b''.join(v+bytes(1) for v in rocks))
# Single-copy vertical movement: four blank rows on either side of the 14-row
# boulder. Each pre-expanded frame occupies 32 bytes for cheap indexing.
asm.append('.export _rgb_to_atari')
asm.append('_rgb_to_atari = rgb_to_atari')
# Odyssey2 characters and sprites always use the bright palette. RGB 0 is
# visible gray (palette entry 8), not the black background (entry 0).
data('rgb_to_atari',[0x06,0x38,0xc8,0x1c,0x88,0x68,0xb8,0x0e])
data('grid_to_atari',[0x06,0x88,0xc8,0xb8,0x38,0x68,0x1c,0x0e])
# BIOS sound commands and six square-wave patterns, copied as score data.
bios=(root/'reference/o2rom.bin').read_bytes()
sound=bytearray(bios[0x300:0x400]);sound[0x60:]=b0[0x760:0x800]
asm.append('.segment "AUX"')
data('sound_score',sound)
data('sound_waves',bios[0x300:0x328])
data('reverse_bits',[rev(x) for x in range(256)])
asm.append('.segment "RODATA"')
asm.append('.segment "EXTRA"')
cols=[];gaps=[];levels=[];distances=[]
for x in range(256):
 if x<=8:c=0;gap=8-x
 elif x>=146:c=8;gap=146-x
 else:
  c=max(0,(x-2)//16);gap=17+16*c-x
 cols.append(c);gaps.append(gap&255)
for y in range(256):
 lev=1;floor=39
 while floor<y and lev<8:floor+=24;lev+=1
 levels.append(lev);distances.append((floor-y)&255)
data('terrain_column',cols);data('terrain_gap',gaps)
data('terrain_level',levels);data('terrain_distance',distances)
(root/'native/assets.s').write_text('\n'.join(asm)+'\n')
(root/'native/asset-provenance.json').write_text(json.dumps({'pete_frames':frames,'mine_layouts':{'bank':1,'start':'6a3','length':90},'source_sha1':'b979ed0c2b8947f764786fcf4444463b3d3ae87d'},indent=2))
