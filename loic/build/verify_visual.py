#!/usr/bin/env python3
"""Run a rendered Godot check under an isolated TCP-only Xvfb display."""
import argparse,os,subprocess,time,tempfile
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--project',type=Path,required=True)
p.add_argument('--godot',required=True)
p.add_argument('--xvfb-root',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--script',default='res://loic/tests/capture.gd')
p.add_argument('--local-ai',action='store_true')
p.add_argument('--size',default='1280x720')
a=p.parse_args()
env=os.environ.copy()
env.update(DISPLAY='127.0.0.1:99',LD_LIBRARY_PATH=str(a.xvfb_root/'usr/lib/x86_64-linux-gnu'),LOIC_SKIP_PROFILE='1',LOIC_CAPTURE_PATH=str(a.output),XDG_DATA_HOME=tempfile.mkdtemp(prefix='loic-visual-'))
env['LOIC_DISABLE_AI']='0' if a.local_ai else '1'
env['LOIC_USE_LOCAL']='1' if a.local_ai else '0'
with a.output.with_suffix('.xvfb.log').open('w') as log:
 x=subprocess.Popen([str(a.xvfb_root/'usr/bin/Xvfb'),':99','-screen','0',a.size+'x24','-ac','-listen','tcp','-nolisten','unix','-nolisten','local','-xkbdir','/usr/share/X11/xkb'],env=env,stdout=log,stderr=subprocess.STDOUT)
 try:
  time.sleep(0.5)
  with a.output.with_suffix('.log').open('w') as game_log:
   r=subprocess.run([a.godot,'--path',str(a.project),'--resolution',a.size,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--script',a.script],env=env,stdout=game_log,stderr=subprocess.STDOUT,timeout=180)
  print(a.output.with_suffix('.log').read_text()[-6000:])
  raise SystemExit(r.returncode)
 finally:x.terminate();x.wait(timeout=5)
