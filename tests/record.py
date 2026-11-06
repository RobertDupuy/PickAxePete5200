from environment import *
from emulator import Emulator
O=R/'evidence/movie';O.mkdir(exist_ok=True)
cmd=['physical_key down Left Ctrl','wait_frames 6','physical_key up Left Ctrl','wait_frames 8']
state=set()
# Ordinary repeated direction and jump attempts; no game-memory writes.
for i in range(900):
 t=i*2
 direction='Right' if (t//110)%2 else 'Left'
 desired={direction}
 if t%86<16:desired.add('Left Ctrl')
 if 440<t%700<490:desired.add('Up')
 if 510<t%700<550:desired.add('Down')
 for k in sorted(state-desired):cmd.append('physical_key up '+k)
 for k in sorted(desired-state):cmd.append('physical_key down '+k)
 state=desired
 cmd+=['wait_frames 2',f'screenshot {O}/frame-{i:04d}.png']
e=Emulator(O,R/'native/build5200/PickAxePete5200.car',boot_frames=600,extra_commands=cmd,capture_audio=O/'audio.wav')
try:
 S=json.loads((R/'native/build5200/symbols.json').read_text())
 report={'video_frames':900,'emulated_frames':1800,'ntsc_rate':1789772.5/(114*262),'missed_frames':int.from_bytes(e.a.peek(S['missed_frames'],2),'little'),'method':'Physical keyboard mapped to controller. No game RAM writes, cheats, or state loading.','audio_start_tick':e.audio_start_tick,'audio_end_tick':e.audio_end_tick}
 (O/'recording.json').write_text(json.dumps(report,indent=2));print(report)
finally:e.close()
