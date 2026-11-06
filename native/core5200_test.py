"""Run the actual linked NMOS-6502 game code against the portable rule model."""
from pathlib import Path
import ctypes as C,random,json,time
from py65.devices.mpu6502 import MPU
root=Path(__file__).resolve().parents[1];p=root/'native/build5200'
lab={x.split()[2][1:]:int(x.split()[1],16) for x in (p/'labels.txt').read_text().splitlines()}
g=C.CDLL(str(p/'game_host.so'))
mem=bytearray(65536)
b=(p/'PickAxePete5200.bin').read_bytes();mem[0x4000:0xc000]=b
cpu=MPU(memory=mem)
mem[lab['c_sp']:lab['c_sp']+2]=b'\x00\x40';mem[0x46:0x48]=b'\x5d\xa7'
def call(name):
 cpu.pc=lab['_'+name];cpu.sp=0xfd;mem[0x1fe]=0xff;mem[0x1ff]=6;cpu.p=0x20
 count=0
 while cpu.pc!=0x700:
  cpu.step();count+=1
  if count>20000:raise RuntimeError((name,hex(cpu.pc)))
 return count

def setv(name,value):
 C.c_ubyte.in_dll(g,name).value=value&255;mem[lab['_'+name]]=value&255

def check(fields,where):
 for name,size in fields.items():
  expected=bytes((C.c_ubyte*size).in_dll(g,name));actual=bytes(mem[lab['_'+name]:lab['_'+name]+size])
  if expected!=actual:raise AssertionError({'where':where,'field':name,'expected':list(expected),'actual':list(actual)})

floors=(C.c_ubyte*9).in_dll(g,'floors');rng=random.Random(711)
layouts=(root/'reference/pickaxe.bin').read_bytes()[0x2a3:0x2fd]
for n in range(20000):
 for i,v in enumerate(layouts[n%10*9:n%10*9+9]):floors[i]=v;mem[lab['_floors']+i]=v
 for key,value in [('query_x',rng.randrange(5,150)),('query_y',rng.randrange(20,200)),('move_x',rng.randrange(-3,4)),('move_y',rng.randrange(-3,4))]:setv(key,value)
 g.terrain_query();call('terrain_query');check({x:1 for x in ['contact_flags','correction_x','correction_y']},n)
print('20000 native 6502 terrain queries match the ROM-checked rule model')
# Reset all mutable bytes and initialise both engines with the same entropy.
mem[0x80:0x100]=bytes(128);mem[0x800:0x1000]=bytes(2048)
mem[lab['c_sp']:lab['c_sp']+2]=b'\x00\x40';mem[0x46:0x48]=b'\x5d\xa7'
C.c_ubyte.in_dll(g,'entropy_value').value=0
C.c_ubyte.in_dll(g,'entropy_fraction').value=0
C.c_uint.in_dll(g,'elapsed').value=0
g.game_init();call('game_init')
fields={k:1 for k in '''mode frame mine_number mine_color scene_changed name_cursor score_pending difficulty score_changed name_changed pete_x pete_y pete_shape pick_life has_key jump_phase walk_phase walk_clock terrain evade_cooldown last_x last_y ladder_x ladder_y ladder_shape ladder_level ladder_stage ladder_phase ladder_hold on_ladder item_x item_y item_kind item_shape item_age effect_x effect_y effect_phase effect_clock rock_cursor door_cursor death_clock transition_clock sound_event sound_queue entropy_value entropy_fraction effect_shape effect_color effect_size glint_cursor transition_stage'''.split()}
fields.update({'floors':9,'score':4,'high_score':4,'name_chars':6,'rock_x':5,'rock_y':5,'rock_x_energy':5,'rock_y_energy':5,'rock_fall':5,'rock_decay':5,'door_color':3,'door_clock':3,'door_open':3,'item_mask':8})
check(fields,'initial')
visits=set();max_instructions=0
for n in range(5000):
 setv('input_x',[-1,0,1,0][(n//43)%4]);setv('input_y',[-1,0,1,0][(n//71)%4]);setv('input_fire',(n%97)<31)
 setv('input_mine',(n//1000)%10 if n%1000==0 else 255)
 setv('input_name',13 if n%181==0 else 255)
 setv('pete_hits_rock',int(n%59==0));setv('pete_hits_item',int(n%53==0));setv('pete_hits_ladder',int(n%47==0))
 if n%1000==220:
  for k,v in {'mode':1,'has_key':1,'pete_x':77,'pete_y':106,'frame':51}.items():setv(k,v)
 if n%1000==650:
  for k,v in {'mode':2,'death_clock':1}.items():setv(k,v)
 if n%1000==150:setv('score_pending',25)
 g.game_tick();steps=call('game_tick');max_instructions=max(steps,max_instructions)
 check(fields,('tick',n));visits.add(mem[lab['_mode']])
report={'terrain_cases':20000,'terrain_mismatches':0,'integrated_ticks':5000,'state_mismatches':0,'states_visited':sorted(visits),'max_tick_instructions':max_instructions,'state_fields_compared':len(fields)}
(p/'native-core-test.json').write_text(json.dumps(report,indent=2));print(report)
