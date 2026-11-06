"""Read-only controller planning using the unchanged game's C rule model.
No emulator writes or state restore: candidates are evaluated in a separate host model.
"""
import ctypes as C,json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
S=json.loads((R/'native/build5200/symbols.json').read_text())
g=C.CDLL(str(R/'native/build5200/game_host.so'))
fields={k:1 for k in '''mode frame mine_number mine_color scene_changed name_cursor score_pending difficulty score_changed name_changed pete_x pete_y pete_shape pick_life has_key jump_phase walk_phase walk_clock terrain evade_cooldown last_x last_y ladder_x ladder_y ladder_shape ladder_level ladder_stage ladder_phase ladder_hold on_ladder item_x item_y item_kind item_shape item_age effect_x effect_y effect_phase effect_clock rock_cursor door_cursor death_clock transition_clock sound_event sound_queue entropy_value entropy_fraction effect_shape effect_color effect_size glint_cursor transition_stage'''.split()}
fields.update({'floors':9,'score':4,'high_score':4,'name_chars':6,'rock_x':5,'rock_y':5,'rock_x_energy':5,'rock_y_energy':5,'rock_fall':5,'rock_decay':5,'door_color':3,'door_clock':3,'item_mask':8})
arrays={k:(C.c_ubyte*n).in_dll(g,k) for k,n in fields.items()}
v={k:C.c_ubyte.in_dll(g,k) for k in list(fields)+['input_x','input_y','input_fire','input_mine','input_name','pete_hits_rock','pete_hits_item','pete_hits_ladder','fifths'] if fields.get(k,1)==1}
elapsed=C.c_uint.in_dll(g,'elapsed')
def choose(m,wanted,target,ty):
 if m[S['_mode']]!=1:return wanted
 # Only invoke a short lookahead near a boulder, including during a jump.
 x,y=m[S['_pete_x']],m[S['_pete_y']]
 if not any(abs(m[S['_rock_x']+i]-x)<35 and abs(m[S['_rock_y']+i]-y)<22 for i in range(5)):return wanted
 snapshot={k:m[S['_'+k]:S['_'+k]+n] for k,n in fields.items()}
 global predicted
 best=None
 for action in dict.fromkeys([wanted,0,1,2,8,9,10,12,13,14,16,17,18,20,21,22]):
  for k,a in arrays.items():a[:]=snapshot[k]
  elapsed.value=int.from_bytes(m[S['elapsed']:S['elapsed']+2],'little');v['fifths'].value=m[S['fifths']]
  cost=0;prediction=None
  for t in range(72):
   v['input_x'].value=(int(bool(action&1))-int(bool(action&2)))&255
   v['input_y'].value=(int(bool(action&16))-int(bool(action&8)))&255
   v['input_fire'].value=int(bool(action&4));v['input_mine'].value=255;v['input_name'].value=255
   v['pete_hits_rock'].value=1;v['pete_hits_item'].value=1
   v['pete_hits_ladder'].value=int(v['ladder_stage'].value>3)
   g.game_tick()
   if t==5:prediction=(v["pete_x"].value,v["pete_y"].value,v["mode"].value)
   if v['mode'].value==2:cost+=10000+(72-t)*100;break
   if v['mode'].value==3:cost-=10000;break
   if not v['pick_life'].value:
    xx,yy=v['pete_x'].value,v['pete_y'].value
    for rx,ry in zip(arrays['rock_x'],arrays['rock_y']):
     if abs(yy-ry)<6 and abs(xx-rx)<7:cost+=12
  # Stay on the desired floor; avoid a long jump away from the target.
  cost+=abs(v['pete_x'].value-target)*.8+max(0,v['pete_y'].value-ty)*2
  if action!=wanted:cost+=5
  if action&4:cost+=2
  if best is None or cost<best[0]:best=(cost,action,prediction)
 predicted=best[2]
 return best[1]
