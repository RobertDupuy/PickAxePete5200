from environment import *
from emulator import Emulator
S=json.loads((R/'native/build5200/symbols.json').read_text())
report={'emulator':'AltirraSDL, NTSC 5200, 16K RAM, original four-port BIOS','mines':[],'controls':{}}
car=R/'native/build5200/PickAxePete5200.car'
def held(k,n=12):return ['physical_key down '+k,f'wait_frames {n}','physical_key up '+k,'wait_frames 8']
layouts=(R/'reference/pickaxe.bin').read_bytes()[0x2a3:0x2fd]
for mine in range(10):
 e=Emulator(R/f'evidence/mine-{mine}',car,boot_frames=600,extra_commands=held(str(mine),120))
 try:
  a=e.a;m=a.memdump(0,16384)
  assert m[S['_mine_number']]==mine and m[S['_mode']]==1,(mine,m[S['_mine_number']],m[S['_mode']])
  assert m[S['_frame']]>90,(mine,'key held restarted repeatedly')
  assert m[S['_floors']:S['_floors']+9]==layouts[mine*9:mine*9+9]
  a.frame(600);m=a.memdump(0,16384)
  assert int.from_bytes(m[S['missed_frames']:S['missed_frames']+2],'little')==0
  report['mines'].append(mine);print('mine',mine,'pass',flush=True)
 finally:e.close()
for key,field,val in [('Left','_input_x',255),('Right','_input_x',1),('Up','_input_y',255),('Down','_input_y',1),('F3','paused',1),('F4','_mode',0)]:
 cmd=held('Left Ctrl')+['physical_key down '+key,'wait_frames 60']
 e=Emulator(R/f'evidence/control-{key}',car,boot_frames=600,extra_commands=cmd)
 try:
  a=e.a;m=a.memdump(0,16384);actual=m[S[field]]
  assert actual==val,(key,field,actual,val)
  if key=='F3':
   before=m[S['_frame']];a.frame(60);assert a.peek(S['_frame'])[0]==before
  report['controls'][key]=True;print(key,'pass',flush=True)
 finally:e.close()
(R/'evidence/acceptance.json').write_text(json.dumps(report,indent=2))
