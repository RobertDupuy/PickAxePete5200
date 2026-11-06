from pathlib import Path
import os,json,sys
R=Path(__file__).resolve().parents[1]
for name in ['ALTIRRA_BRIDGE_SDK','ALTIRRA_SDL','ATARI5200_BIOS']:
 if name not in os.environ:raise RuntimeError('Set '+name+' to a local installation')
os.environ.setdefault('SDL_AUDIODRIVER','dummy')
os.environ.setdefault('SDL_VIDEODRIVER','dummy')
os.environ.setdefault('ALTIRRA_FRONTEND_SHIM',str(R/'tests/frontend_tcp.so'))
