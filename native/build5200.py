from pathlib import Path
import subprocess,struct,os,json
root=Path(__file__).resolve().parents[1];os.chdir(root)
cc=Path(os.environ.get('CC65_BIN',str(root/'tools/cc65/bin')))
out=root/'native/build5200';out.mkdir(exist_ok=True)
def run(args):subprocess.run([str(x) for x in args],check=True)
for f in ('extract_assets','generate_fixed','generate_hud','generate_select','port5200'):run(['python3','native/'+f+'.py'])
run([cc/'cc65','-t','none','-D','PICKAXE_5200','-Oirs','--static-locals','-g','native/game.c','-o',out/'game.s'])
files=('platform','assets','hud_generated','terrain','objects','contacts','audio','entropy','select')
for f in files:run([cc/'ca65','-g','-I','native/5200','-I','native','native/5200/'+f+'.s','-o',out/(f+'.o')])
run([cc/'ca65','-g','-I','native',out/'game.s','-o',out/'game.o'])
# 20 BIOS character cells followed by the two copyright digits and entry vector.
(root/'native/tail5200.s').write_text('.import start\n.segment "TAIL"\n.byte '+','.join(str(ord(c)+32) for c in 'PICK AXE PETE'.center(20))+',88,82\n.word start\n')
run([cc/'ca65','native/tail5200.s','-o',out/'tail.o'])
run([cc/'ld65','-C','native/link5200.cfg','-m',out/'map.txt','-Ln',out/'labels.txt','-o',out/'PickAxePete5200.bin',*[out/(f+'.o') for f in files],out/'game.o',out/'tail.o',cc.parent/'lib/none.lib'])
b=(out/'PickAxePete5200.bin').read_bytes();assert len(b)==32768
(out/'PickAxePete5200.car').write_bytes(b'CART'+struct.pack('>III',4,sum(b)&0xffffffff,0)+b)
labels={line.split()[2][1:]:int(line.split()[1],16) for line in (out/'labels.txt').read_text().splitlines()}
(out/'symbols.json').write_text(json.dumps(labels,indent=2))
print('Built 32K Atari 5200 cartridge')
