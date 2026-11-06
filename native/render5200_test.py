"""Independent pixel and PMG memory oracle for the linked 6502 renderer."""
from pathlib import Path
import json, random
import numpy as np
from py65.devices.mpu6502 import MPU
root=Path(__file__).resolve().parents[1]; p=root/'native/build5200'
lab={x.split()[2][1:]:int(x.split()[1],16) for x in (p/'labels.txt').read_text().splitlines()}
m=bytearray(65536)
m[0x4000:0xc000]=(p/'PickAxePete5200.bin').read_bytes()
for name,dest,size in [('RAMCODE',0x3000,1024),('HUDFONT',0x2c00,1024)]:
 src=lab['__'+name+'_LOAD__'];m[dest:dest+size]=m[src:src+size]
cpu=MPU(memory=m)
m[lab['c_sp']:lab['c_sp']+2]=b'\x00\x40'
def call(name):
 cpu.pc=lab[name];cpu.sp=0xfd;m[0x1fe]=255;m[0x1ff]=6;cpu.p=0x24
 for _ in range(200000):
  if cpu.pc==0x700:return
  cpu.step()
 raise RuntimeError(name)
def put(name,values):
 if isinstance(values,int):values=[values&255]
 m[lab[name]:lab[name]+len(values)]=bytes(values)
def get(name):return m[lab[name]]
call('_game_init');put('_mode',1);call('scene_setup')
rng=random.Random(8048)
def decode(base):
 codes=np.frombuffer(m,dtype=np.uint8,count=880,offset=base).reshape(22,40)
 font=np.frombuffer(m,dtype=np.uint8,count=1024,offset=get('font_page')*256).reshape(128,8)
 rows=font[codes&127].transpose(0,2,1).reshape(176,40)
 return np.stack([(rows>>k)&3 for k in (6,4,2,0)],axis=-1).reshape(176,160)
checks=0; max_work=0
ys=[40,65,90,125,165]
for frame in range(250):
 xs=[rng.randrange(10,140) for _ in range(5)]
 if frame%4==0:xs=[74,76,78,80,82] # shared cells and overlaid doors
 for i in range(5):
  if frame%11==0:ys[i]=rng.randrange(30,180)
  else:ys[i]=max(28,min(180,ys[i]+rng.choice([-4,-2,0,2,4])))
 visible=[248 if (frame+i)%19==0 else ys[i] for i in range(5)]
 put('_rock_x',xs);put('_rock_y',visible);put('_frame',frame)
 put('_door_open',[int(frame%7==0),int(frame%9==0),int(frame%11==0)])
 for key,value in {'pete_x':60,'pete_y':ys[0],'pete_shape':frame%37,'ladder_x':90,'ladder_y':ys[1],
                   'ladder_shape':frame%4,'pick_life':0,'item_kind':2,'item_x':120,'item_y':ys[2],
                   'item_shape':4+frame%4,'effect_x':40,'effect_y':ys[3],
                   'effect_shape':frame%2,'effect_size':int(frame%13<4),'effect_color':frame%8}.items():put('_'+key,value)
 put('_item_mask',[rng.randrange(256) for _ in range(8)])
 for f in ['prepare_sprites','pm_prepare','prepare_effects','rocks_prepare','rocks_commit','pm_commit']:call(f)
 expected=decode(0x1000)
 shape=0 if frame&3 else (16 if frame&16 else 8)
 art=m[lab['_rock_glyphs']+shape:lab['_rock_glyphs']+shape+7]
 for x,y in zip(xs,visible):
  if y==248:continue
  y=(y&254)-24;x+=2
  for dy in range(14):
   for dx in range(8):
    if art[dy//2]&(128>>dx) and 0<=y+dy<176:expected[y+dy,x+dx]=3
 actual=decode(0x1400)
 if not np.array_equal(actual,expected):
  bad=np.argwhere(actual!=expected)
  raise AssertionError({'frame':frame,'first_pixels':bad[:12].tolist(),'actual':[int(actual[tuple(v)]) for v in bad[:12]],'expected':[int(expected[tuple(v)]) for v in bad[:12]]})
 for player in range(4):
  expected_pm=bytearray(256);height=m[lab['pm_height']+player];top=m[lab['pm_y']+player]+16
  repeat=4 if player==3 and get('_effect_size') else 2
  if height:
   pixels=bytes(v for v in m[lab['pm_pattern']+player*8:lab['pm_pattern']+player*8+8] for _ in range(repeat))
   expected_pm[top:min(256,top+len(pixels))]=pixels[:max(0,256-top)]
  actual_pm=m[0x1c00+player*256:0x1d00+player*256]
  assert actual_pm==expected_pm,{'frame':frame,'player':player,'rows':[i for i in range(256) if actual_pm[i]!=expected_pm[i]][:12]}
 checks+=176*160+1024;max_work=max(max_work,get('work_count'))
 assert get('work_count')<=45 and get('queue_overflow')==0
report={'frames':250,'pixel_and_pmg_byte_checks':checks,'max_working_glyphs':max_work,'mismatches':0}
(p/'fixed-render-test.json').write_text(json.dumps(report,indent=2));print(report)
