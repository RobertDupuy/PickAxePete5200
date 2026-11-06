from pathlib import Path
import os,json,sys
R=Path(__file__).resolve().parents[1]
for key in ('ALTIRRA_BRIDGE_SDK','ALTIRRA_SDL','ATARI5200_BIOS'):
 if key not in os.environ: raise RuntimeError('Set '+key+' to your local emulator dependency')
os.environ.setdefault('SDL_AUDIODRIVER','dummy')
os.environ.setdefault('SDL_VIDEODRIVER','dummy')
