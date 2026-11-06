from local_env import *
from live import Frontend
from lookahead import choose
S=json.loads((R/'native/build5200/symbols.json').read_text())
rom=(R/'native/build5200/PickAxePete5200.bin').read_bytes();off=S['static_font']-0x4000;expected=rom[off:off+1968]
e=Frontend(R/'evidence/campaign-v5',Path(os.environ['ALTIRRA_SDL']),record=True)
a=e.a;max_work=0;events=[];last=None;clears=0;deaths=0;target=76
try:
 m=e.step(4,8)
 for f in range(0,90000,6):
  def g(k):return m[S['_'+k]]
  x,y=g('pete_x'),g('pete_y');lx,ly=g('ladder_x'),g('ladder_y');ix,iy=g('item_x'),g('item_y');key=g('has_key');pick=g('pick_life');mode=g('mode')
  state=(mode,key,pick>0,g('item_kind'))
  if state!=last or f%600==0:
   v={'f':f,'state':state,'pete':[x,y],'ladder':[lx,ly,g('ladder_stage')],'item':[ix,iy],'score':list(m[S['_score']:S['_score']+4]),'clears':clears,'floors':list(m[S['_floors']:S['_floors']+9]),'missed_frames':int.from_bytes(m[S['missed_frames']:S['missed_frames']+2],'little')}
   print(json.dumps(v),flush=True);events.append(v)
  if last and last[0]==3 and mode==1:
   clears+=1;a.screenshot(path=str(e.out/f'clear-{clears}.png'));print('CLEARED',clears,flush=True)
   if clears==5:
    m=e.step(0,120);break
  if last and last[0]!=2 and mode==2:deaths+=1;clears=0
  last=state
  if mode!=1:action=4 if mode==0 else 0
  else:
   target_y=34
   if key:target=77;target_y=178 if y>=172 else (106 if y>=100 else 34)
   elif g('item_kind')==2:target=ix;target_y=28
   elif pick:target=40;target_y=34
   else:target=40;target_y=34
   action=0
   # Ascend using the moving ladders; seek the current ladder at this height.
   if y>target_y+7:
    if lx<150 and abs(y-ly)<17:
     target=lx-1
     if abs(x-target)<7:action|=8;target=x
   if abs(x-target)>3:action|=1 if target>x else 2
   if key and abs(x-77)<7 and abs(y-target_y)<8:action|=16 if y<target_y else 0
   # Jump over approaching boulders when away from a ladder.
   threats=[(m[S['_rock_x']+i],m[S['_rock_y']+i]) for i in range(5)]
   if not pick and not (action&8) and not g('jump_phase') and any(abs(rx-x)<12 and abs(ry-y)<7 for rx,ry in threats):action=8|4
  import lookahead
  lookahead.predicted=None
  if mode==1:action=choose(m,action,target,target_y)
  m=e.step(action,6)
  if lookahead.predicted:
   p=lookahead.predicted;actual=tuple(m[S['_'+k]] for k in ['pete_x','pete_y','mode'])
   if abs(p[0]-actual[0])>3 or abs(p[1]-actual[1])>3 or p[2]!=actual[2]:print('PRED-MISMATCH',f,action,p,actual,flush=True)
  if f%600==0:a.screenshot(path=str(e.out/f'progress-{f}.png'))
  max_work=max(max_work,m[S['work_count']])
  if m[S['display_ready']]:
   actual=b''.join(m[0x2000+i*1024:0x2000+i*1024+656] for i in range(3))
   if actual!=expected:
    print('CORRUPT',f,flush=True);a.screenshot(path=str(e.out/'corrupt.png'));(e.out/'corrupt-ram.bin').write_bytes(m);break
 finally_dummy=0
finally:
 (e.out/'result.json').write_text(json.dumps({'clears':clears,'deaths':deaths,'frames':e.frames,'rom_sha256':e.car_sha256,'missed_frames':int.from_bytes(m[S['missed_frames']:S['missed_frames']+2],'little'),'max_work':max_work},indent=2))
 (e.out/'events.json').write_text(json.dumps(events,indent=2));e.close()
 print('RESULT',clears,deaths,flush=True)
