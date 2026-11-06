"""Decode the actual ANTIC 4 HUD glyphs and compare their pixels to source art."""
from pathlib import Path
import re,json
from py65.devices.mpu6502 import MPU
root=Path(__file__).resolve().parents[1];p=root/'native/build5200'
lab={x.split()[2][1:]:int(x.split()[1],16) for x in (p/'labels.txt').read_text().splitlines()}
m=bytearray(65536)
m[0x4000:0xc000]=(p/'PickAxePete5200.bin').read_bytes()
for name,dest,size in [('RAMCODE',0x3000,1024),('HUDFONT',0x2c00,1024)]:
 src=lab['__'+name+'_LOAD__'];m[dest:dest+size]=m[src:src+size]
cpu=MPU(memory=m);m[lab['c_sp']:lab['c_sp']+2]=b'\x00\x40'
def call(name):
 cpu.pc=lab[name];cpu.sp=0xfd;m[0x1fe]=255;m[0x1ff]=6;cpu.p=0x24
 for _ in range(1000000):
  if cpu.pc==0x700:return
  cpu.step()
 raise RuntimeError(name)
raw=(root/'reference/o2em-cset.c').read_text().split('uint8_t cset[512]= {')[1].split('}')[0];font=bytes(int(x,16) for x in re.findall(r'0x([a-fA-F0-9]+)',raw))
call('_game_init');call('hud_scene');m[lab['hud_shadow']:lab['hud_shadow']+14]=b'\xff'*14
xs=[17,25,33,41,113,121,129,137,57,65,73,81,89,97]
checks=0
for c in range(46):
 chars=[c%10]*8+[c]*6
 m[lab['_high_score']:lab['_high_score']+4]=bytes(chars[:4]);m[lab['_score']:lab['_score']+4]=bytes(chars[4:8]);m[lab['_name_chars']:lab['_name_chars']+6]=bytes(chars[8:])
 m[lab['_score_changed']]=m[lab['_name_changed']]=1;call('prepare_hud');call('commit_hud')
 for field,x0 in enumerate(xs):
  for y in range(16):
   for px in range(8):
    x=x0+px;code=m[0x1770+(y//8)*40+x//4];data=m[0x2c00+code*8+(y&7)];actual=(data>>(6-2*(x&3)))&3
    expected=(2 if field<4 else 3) if y<14 and font[chars[field]*8+y//2]&(128>>px) else 0
    assert actual==expected,(c,field,px,y,actual,expected)
    checks+=1
(p/'hud-test.json').write_text(json.dumps({'characters':46,'pixel_checks':checks,'mismatches':0},indent=2));print(checks,'HUD pixels match the original artwork')
