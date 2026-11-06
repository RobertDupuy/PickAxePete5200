"""Controller-only completion attempt on AltirraSDL with the original BIOS.
Inputs use its physical-key frontend. RAM is observed for targeting and telemetry;
there are no memory writes, invulnerability, stage skips, or loaded states.
The player decides at eight-frame intervals, with ordinary fire edges and shield.
"""
from pathlib import Path
import os,sys,json,subprocess,select,re,time,shutil,random,argparse,hashlib,socket
sys.path.insert(0,os.environ['ALTIRRA_BRIDGE_SDK'])
from altirra_bridge import AltirraBridge
R=Path(__file__).resolve().parents[1]
class Frontend:
 def __init__(self,out,exe,record=False):
  self.out=out;out.mkdir(parents=True,exist_ok=True);self.frames=0;self.previous=0;self.actions=[];self.record=record
  from emulator import make_config
  make_config(out)
  self.car_sha256=hashlib.sha256((R/'native/build5200/PickAxePete5200.car').read_bytes()).hexdigest()
  ir,iw=os.pipe();orr,ow=os.pipe()
  env=dict(os.environ,XDG_CONFIG_HOME=str(out/'config'),ALTIRRA_TESTMODE_IN_FD=str(ir),ALTIRRA_TESTMODE_OUT_FD=str(ow))
  for k in ['ALTIRRA_TESTMODE_SCRIPT','ALTIRRA_TESTMODE_OUTPUT','LD_PRELOAD']:env.pop(k,None)
  if os.environ.get('ALTIRRA_FRONTEND_SHIM'):env['LD_PRELOAD']=os.environ['ALTIRRA_FRONTEND_SHIM']
  self.log=(out/'frontend.log').open('w')
  self.proc=subprocess.Popen([str(exe),'--headless','--test-mode','--renderer','sdlrenderer','--bridge=tcp:127.0.0.1:0','--hardware','5200','--memsize','16k','--kernelref','Original Atari 5200 four-port BIOS','--ntsc','--cart',str(R/'native/build5200/PickAxePete5200.car')],env=env,stdout=self.log,stderr=self.log,pass_fds=(ir,ow))
  os.close(ir);os.close(ow)
  if os.environ.get('ALTIRRA_FRONTEND_SHIM'):
   os.close(iw);os.close(orr)
   for _ in range(300):
    text=(out/'frontend.log').read_text();port=re.search(r'loopback-port: ([0-9]+)',text)
    if port:break
    if self.proc.poll() is not None:raise RuntimeError('frontend startup failed')
    time.sleep(.02)
   else:raise RuntimeError('frontend startup timeout')
   self.sock=socket.create_connection(('127.0.0.1',int(port[1])),timeout=40)
   self.sock.setsockopt(socket.IPPROTO_TCP,socket.TCP_NODELAY,1)
   self.uw=self.sock.makefile('wb',buffering=0);self.ur=self.sock.makefile('rb',buffering=0)
  else:
   self.uw=os.fdopen(iw,'wb',buffering=0);self.ur=os.fdopen(orr,'rb',buffering=0)
  self.ui('pause');self.ui('set_speed 800');self.ui('set_window_size 336 256');self.ui('wait_frames 2')
  log=(out/'frontend.log').read_text();self.a=AltirraBridge();self.a.connect(re.search(r'listening on (tcp:\S+)',log)[1]);self.a.hello(re.search(r'\[Bridge\] token: (\S+)',log)[1]);self.a.pause()
  if record:self.start_recording()
  self.a.cold_reset();self.a.frame(400);self.a.ping();self.frames=400
  self.a.screenshot(path=str(out/'boot.png'))
 def ui(self,cmd):
  self.uw.write((cmd+'\n').encode())
  if not select.select([self.ur],[],[],40)[0]:raise RuntimeError('UI timeout '+cmd)
  r=json.loads(self.ur.readline());assert r.get('ok'),(cmd,r)
  return r
 def start_recording(self):
  def click(w,l):self.ui(f'click "{w}" "{l}"');self.ui('wait_frames 5')
  def enter(w,l,s,submit=False):
   click(w,l);self.ui('key ctrl+a');self.ui('wait_frames 3');self.ui('send_text '+str(s));self.ui('wait_frames 3')
   if submit:self.ui('key enter');self.ui('wait_frames 5')
  self.ui('file_dialog_builtin on');self.ui('set_window_size 1280 900');self.ui('wait_frames 5')
  click('##MainMenuBar','Record');click('Record###Menu_00','Record Video...');click('Record Video','Record')
  enter('Save File','##path',self.out,True);enter('Save File','##filename','native-capture.avi');click('Save File','Save')
  self.ui('set_window_size 336 256');self.a.pause()
 def step(self,action,n=8):
  keys={1:'Right',2:'Left',4:'Left Ctrl',8:'Up',16:'Down'};changed=action!=self.previous
  if changed:
   for bit,key in keys.items():
    if (action^self.previous)&bit:self.ui(f'physical_key {"down" if action&bit else "up"} {key}')
   self.ui('wait_frames 1');self.a.pause()
  self.actions.append([self.frames,n,action]);self.previous=action
  self.a.frame(n-int(changed));self.a.ping();self.frames+=n
  return self.a.peek(0,16384)
 def close(self):
  if self.record:
   self.ui('click "##MainMenuBar" "Record"');self.ui('wait_frames 5');self.ui('click "Record###Menu_00" "Stop Recording"');self.ui('wait_frames 5')
  self.a.quit();self.proc.wait(timeout=30);self.log.close();(self.out/'controller-inputs.json').write_text(json.dumps(self.actions))
