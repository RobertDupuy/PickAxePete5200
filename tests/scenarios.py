from environment import *
from emulator import Emulator
S=json.loads((R/'native/build5200/symbols.json').read_text())
e=Emulator(R/'evidence/scenarios',R/'native/build5200/PickAxePete5200.car',boot_frames=600,extra_commands=['physical_key down Left Ctrl','wait_frames 10','physical_key up Left Ctrl','wait_frames 40'])
a=e.a
try:
 def get(k,n=1):return a.peek(S[k],n)
 def boundary():
  a.bp_clear_all();a.bp_set(S['frame_begin']);a.cycles(200000);assert int(a.regs()['PC'][1:],16)==S['frame_begin'];a.bp_clear_all()
 def put(d):
  for k,v in d.items():a.memload(S[k],bytes(v if isinstance(v,list) else [v]))
 boundary();put({'_has_key':1,'_pete_x':77,'_pete_y':106,'_frame':51})
 oldfloors=get('_floors',9);a.frame(10);assert get('_mode')[0]==3
 transition=0
 for i in range(300):
  a.frame(1)
  if get('_mode')[0]!=3:break
  assert not any(a.peek(0x1d00,768)),('stale objects',i)
  transition+=1
  if i==20:a.screenshot(path=str(R/'evidence/transition.png'))
 assert transition>200 and get('_mode')[0]==1
 a.frame(20);assert get('_floors',9)!=oldfloors
 a.screenshot(path=str(R/'evidence/new-mine.png'))
 boundary();put({'_score':[0,0,4,2],'_mode':2,'_death_clock':1})
 a.frame(220);assert list(get('_high_score',4))==[0,0,4,2];assert get('_mode')[0]==1
 assert get('_name_chars',6)==bytes([15,14,44,19,1,12])
 assert get('_name_cursor')[0]==255
 a.screenshot(path=str(R/'evidence/high-score.png'))
 before=int.from_bytes(get('missed_frames',2),'little');a.frame(6000)
 after=int.from_bytes(get('missed_frames',2),'little');assert after==before==0,(before,after)
 report={'transition_frames_checked':transition,'stale_player_bytes':0,'floor_removed':True,'high_score_after_death':42,'extended_gameplay_frames':6000,'missed_frames':after,'fixtures':'Key/door position and death-score cases seeded in RAM; game code handles outcomes. Long run uses normal game execution.'}
 (R/'evidence/scenarios.json').write_text(json.dumps(report,indent=2));print(report)
finally:e.close()
