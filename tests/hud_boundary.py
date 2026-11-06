from local_env import *
from emulator import Emulator
from PIL import Image
S=json.loads((R/'native/build5200/symbols.json').read_text())
O=R/'evidence/hud-boundary';O.mkdir(exist_ok=True)
rom=(R/'native/build5200/PickAxePete5200.bin').read_bytes()
def separator_geometry():
 # ANTIC starts the display list at physical scanline 8. Decode the linked
 # bytes, including each LMS operand, so an accidental row-height change fails.
 p=S['fixed_dlist'];line=8;rows=[]
 while p<S['fixed_dlist_end']:
  op=rom[p-0x4000];p+=1;mode=op&15
  if mode==1:break
  height=((op>>4)&7)+1 if mode==0 else {4:8,14:1}[mode]
  if mode and op&0x40:p+=2
  rows.append((line,height,mode,bool(op&0x80)));line+=height
 strip=[row for row in rows if 208<=row[0]<216]
 assert strip==[(208,1,14,False),(209,1,14,False),(210,1,14,False),(211,3,0,True),(214,2,0,False)],strip
 assert (216,8,4,False) in rows and (224,8,4,False) in rows
 return {'floor_scanlines':[208,209,210],'blank_scanlines':[211,212,213,214,215],'hud_dli_scanline':213,'hud_first_scanline':216}
def check_separator_pixels(path):
 # Altirra's 336x224 capture starts at physical scanline 16. Exclude the
 # player/missile side walls; the complete five-line interior must be black.
 im=Image.open(path).convert('RGB');assert im.size==(336,224),im.size
 blank=im.crop((30,195,311,200));assert blank.getbbox() is None,path
 return blank.width*blank.height
geometry=separator_geometry()
cmd=['physical_key down Left Ctrl','wait_frames 6','physical_key up Left Ctrl','wait_frames 120',
 'physical_key down -','wait_frames 6','physical_key up -','wait_frames 12',
 'physical_key down =','wait_frames 6','physical_key up =','wait_frames 12']
e=Emulator(O,R/'native/build5200/PickAxePete5200.car',boot_frames=400,extra_commands=cmd)
a=e.a
try:
 expected=bytes([15,14,44,19,1,12])
 assert a.peek(S['_name_chars'],6)==expected
 assert a.peek(S['_name_cursor'])[0]==255
 a.screenshot(path=str(O/'PLYR1-start.png'))
 blank_pixels=check_separator_pixels(O/'PLYR1-start.png')
 switches=[]
 for i in range(8):
  a.bp_set(S['hud_font_switch']);a.cycles(100000)
  regs=a.regs();assert int(regs['PC'][1:],16)==S['hud_font_switch'],regs
  switches.append(a.antic())
  assert switches[-1]['beam_y']<geometry['hud_first_scanline'],switches[-1]
  a.bp_clear_all();a.cycles(20);a.ping()
 print('HUD switch:',switches[0],flush=True)
 a.bp_set(S['frame_begin']);a.cycles(100000);assert int(a.regs()['PC'][1:],16)==S['frame_begin'];a.bp_clear_all()
 # Fixture solely to check the actual game-over/high-score path.
 for name,value in {'_score':[0,0,4,2],'_mode':[2],'_death_clock':[95]}.items():a.memload(S[name],bytes(value))
 a.frame(20);a.ping()
 assert a.peek(S['_name_chars'],6)==expected
 assert list(a.peek(S['_high_score'],4))==[0,0,4,2]
 assert a.peek(S['_name_cursor'])[0]==255
 a.screenshot(path=str(O/'PLYR1-high-score.png'))
 blank_pixels+=check_separator_pixels(O/'PLYR1-high-score.png')
 a.frame(1800);a.ping();assert a.peek(S['_name_chars'],6)==expected
 missed=int.from_bytes(a.peek(S['missed_frames'],2),'little')
 a.screenshot(path=str(O/'PLYR1-extended.png'))
 # A normal explosion can overlap the separator. Disable PMG for this final
 # background-only capture so sprite pixels are not mistaken for glyph junk.
 a.memload(0xc01d,b'\x00');a.frame(2);a.ping()
 a.screenshot(path=str(O/'PLYR1-background.png'))
 a.memload(0xc01d,b'\x03')
 blank_pixels+=check_separator_pixels(O/'PLYR1-background.png')
 assert missed==0,missed
 report={'fixed_label':'PLYR1','glyph_codes':list(expected),'name_entry_disabled':True,'start_label_correct':True,'high_score_label_correct':True,'post_restart_frames':1800,'missed_frames':missed,'separator_geometry':geometry,'blank_pixel_checks':blank_pixels,'hud_switch_samples':switches,'fixtures':'Death and score are seeded solely to exercise high-score saving; keypad */# use physical controller inputs. PMG is temporarily disabled only for the final background-only screenshot, to exclude normal overlapping sprite effects.'}
 (O/'report.json').write_text(json.dumps(report,indent=2));print(report,flush=True)
finally:e.close()
