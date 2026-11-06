"""Exercise linked 6502 interrupt code through the original BIOS NMI dispatcher.
Omit individual DLIs deliberately and require the next frame to recover.
This is interrupt fault injection, not a claim of controller-play reproduction.
"""
from pathlib import Path
import json,os,sys
from py65.devices.mpu6502 import MPU
R=Path(__file__).resolve().parents[1]
BIOS=Path(os.environ['ATARI5200_BIOS']).read_bytes()
class TraceMemory(bytearray):
 def __init__(self):
  super().__init__(65536);self.exposed_writes=0
 def __setitem__(self,k,v):
  if isinstance(k,int) and (0x400<=k<0x480 or 0xc00<=k<0x2c00) and self[0xd40e]&0xc0:self.exposed_writes+=1
  super().__setitem__(k,v)
def run(build,robust):
 s=json.loads((build/'symbols.json').read_text());rom=(build/'PickAxePete5200.bin').read_bytes();results=[]
 for omitted in range(16):
  m=TraceMemory();m[0x4000:0xc000]=rom;m[0xf800:]=BIOS
  for name,dest,size in [('RAMCODE',s['__RAMCODE_RUN__'],s['__RAMCODE_SIZE__']),('HUDFONT',0x2c00,1024)]:
   p=s['__'+name+'_LOAD__'];m[dest:dest+size]=m[p:p+size]
  cpu=MPU(memory=m);m[s['c_sp']:s['c_sp']+2]=b'\x00\x40'
  def until():
   for _ in range(100000):
    if cpu.pc==0x700:return
    cpu.step()
   raise AssertionError(hex(cpu.pc))
  def call(name):
   cpu.pc=s[name];cpu.sp=0xfd;m[0x1fe:0x200]=b'\xff\x06';cpu.p=0x24;until()
  call('_game_init');m[s['_mode']]=1;m[0xd40e]=0xc0;start=cpu.processorCycles;call('scene_setup');setup_cycles=cpu.processorCycles-start;setup_exposed=m.exposed_writes
  if robust:assert m.exposed_writes==0
  for vector,target in [(0x202,'nmi'),(0x206,'dli_entry')]:m[vector:vector+2]=s[target].to_bytes(2,'little')
  def interrupt(line,dli):
   cpu.pc=0x700;cpu.sp=0xff;cpu.p=0x20;cpu.a=0x47;cpu.x=0x93;cpu.y=0xa6
   m[0xd40b]=line//2;m[0xd40f]=0x80 if dli else 0x40
   cpu.nmi();until()
   assert (cpu.a,cpu.x,cpu.y,cpu.sp)==(0x47,0x93,0xa6,0xff)
  # Stable palette and a ready frame; actual linked code does all commits.
  dli_lines=[119,191,213 if robust else 215,234]
  for i,line in enumerate(dli_lines):
   if not (omitted>>i)&1:interrupt(line,True)
  interrupt(248,False)
  first_font=m[0xd409]
  phases=[]
  for line in dli_lines:
   interrupt(line,True);phases.append(m[0xd409])
  recovered=first_font==m[s['live_font_page']] and phases[:3]==[m[s['live_font_page']],m[s['live_font_page']],0x2c] and phases[3]==m[s['live_font_page']]
  if robust:assert recovered,(omitted,first_font,phases)
  results.append({'omitted_dli_mask':omitted,'next_frame_font':first_font,'next_frame_phase_fonts':phases,'recovered':recovered,'scene_setup_cpu_cycles':setup_cycles,'scene_writes_with_nmi_enabled':setup_exposed})
 return results
old=run(Path(sys.argv[1]),False) if len(sys.argv)>1 else None
new=run(R/'native/build5200',True)
report={'method':__doc__,'before':old,'after':new,'before_failed_cases':sum(not a['recovered'] for a in old) if old is not None else None,'after_failed_cases':sum(not a['recovered'] for a in new),'preserved_cpu_registers':True}
(R/'evidence/interrupt-regression.json').write_text(json.dumps(report,indent=2));print('Old failures:',report['before_failed_cases'],'of 16; corrected failures:',report['after_failed_cases'])
