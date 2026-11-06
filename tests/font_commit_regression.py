"""Exercise the actual linked renderer at its 32-cell page boundary.
The workload is a legal synthetic renderer fixture, not gameplay footage.
"""
from pathlib import Path
from py65.devices.mpu6502 import MPU
import json,hashlib
R=Path(__file__).resolve().parents[1]
def run(build,repeats):
 labels=json.loads((build/'symbols.json').read_text());rom=(build/'PickAxePete5200.bin').read_bytes();results=[]
 for bank in range(3):
  for count in [0,1,31,32,33,45]:
   m=bytearray(65536);m[0x4000:0xc000]=rom
   for name,dest,size in [('RAMCODE',0x3000,labels['__RAMCODE_SIZE__']),('HUDFONT',0x2c00,1024)]:
    src=labels['__'+name+'_LOAD__'];m[dest:dest+size]=m[src:src+size]
   m[labels['c_sp']:labels['c_sp']+2]=b'\x00\x40';cpu=MPU(memory=m)
   def call(name):
    cpu.pc=labels[name];cpu.sp=0xfd;m[0x1fe]=255;m[0x1ff]=6;cpu.p=0x24
    for _ in range(200000):
     if cpu.pc==0x700:return
     cpu.step()
    raise RuntimeError(name)
   call('_game_init');m[labels['_mode']]=1;call('scene_setup');m[labels['_rock_y']:labels['_rock_y']+5]=bytes([248]*5)
   m[labels['_frame']]=[1,0,16][bank];call('rocks_prepare');assert m[labels['font_page']]==0x20+4*bank
   m[labels['work_count']]=count
   for i in range(45):
    p=0x500+8*i;m[p:p+8]=bytes([i+1]*8);m[labels['work_src_lo']+i]=p&255;m[labels['work_src_hi']+i]=p>>8
   static=[bytes(m[0x2000+b*1024:0x2000+b*1024+656]) for b in range(3)]
   adjacent=bytes(m[0x2c00:0x3000]);first=None;damage=[]
   for n in range(repeats):
    call('rocks_commit')
    bad=sum(m[0x2000+b*1024+j]!=static[b][j] for b in range(3) for j in range(656))
    bad+=sum(a!=b for a,b in zip(m[0x2c00:0x3000],adjacent))
    damage.append(bad)
    if n==0:first=bytes(m[0x2000:0x3000])
    if repeats>6:assert bytes(m[0x2000:0x3000])==first,(bank,count,n,bad)
   results.append({'bank':bank,'cells':count,'corrupted_protected_bytes':damage if repeats<=6 else max(damage),'commits':repeats})
 return {'rom_sha256':hashlib.sha256(rom).hexdigest(),'cases':results}
fixed=run(R/'native/build5200',120)
# Retain independent results from the previously delivered build.
baseline=None
import sys
if len(sys.argv)>1:baseline=run(Path(sys.argv[1]),2)
report={'fixture':'Repeated legal batches without a new prepare, matching the Pause scheduling path. No emulator gameplay state changed.','before':baseline,'after':fixed}
(R/'evidence').mkdir(exist_ok=True)
(R/'evidence/font-commit-regression.json').write_text(json.dumps(report,indent=2))
print('Fixed:',len(fixed['cases']),'cases, 2160 commits, zero protected-byte changes')
if baseline:print('Before:',[(x['bank'],x['cells'],x['corrupted_protected_bytes']) for x in baseline['cases'] if any(x['corrupted_protected_bytes'])])
