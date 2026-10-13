"""Original CC0 sculpted dragon eggs. Smooth shell plus raised shield scales."""
from pathlib import Path
import numpy as np, math, json,struct
OUT=Path(__file__).resolve().parents[1]/'packs/dragon-eggs-original';OUT.mkdir(parents=True,exist_ok=True)
def surface(t,a):
 r=.50*math.sin(t)*(1-.20*math.cos(t));y=.80*(1+math.cos(t))
 return np.array([r*math.cos(a),y,r*math.sin(a)])
def normal(t,a):
 e=.00001;v=np.cross(surface(t+e,a)-surface(t-e,a),surface(t,a+e)-surface(t,a-e));return -v/np.linalg.norm(v)
def mesh_shell():
 v=[];n=[];ind=[];rows=40;cols=64
 for i in range(rows+1):
  t=.001+(math.pi-.002)*i/rows
  for k in range(cols+1):a=2*math.pi*k/cols;v.append(surface(t,a));n.append(normal(t,a))
 for i in range(rows):
  for k in range(cols):
   a=i*(cols+1)+k;b=a+cols+1;ind.extend([a,b,a+1,a+1,b,b+1])
 return np.array(v,np.float32),np.array(n,np.float32),np.array(ind,np.uint32)
def mesh_scales():
 v=[];n=[];idx=[]
 for row in range(13):
  t=.30+row*.19;cols=max(9,round(25*math.sin(t)))
  for k in range(cols):
   a=2*math.pi*(k+.5*(row%2))/cols;dt=.10;da=(math.pi/cols)*.78
   uv=[(t-dt*.85,a),(t-dt*.35,a-da),(t+dt*.5,a-da*.75),(t+dt,a),(t+dt*.5,a+da*.75),(t-dt*.35,a+da),(t,a)]
   start=len(v)
   for l,(tt,aa) in enumerate(uv):
    no=normal(tt,aa);v.append(surface(tt,aa)+no*(.036 if l==6 else .008));n.append(no)
   for l in range(6):idx.extend([start+6,start+l,start+(l+1)%6])
 return np.array(v,np.float32),np.array(n,np.float32),np.array(idx,np.uint32)
def glb(name,colors):
 binary=bytearray();views=[];acc=[];meshes=[]
 for parts,mat in [(mesh_shell(),0),(mesh_scales(),1)]:
  refs=[]
  for arr,component,type_ in zip(parts,[5126,5126,5125],['VEC3','VEC3','SCALAR']):
   while len(binary)%4:binary.append(0)
   offset=len(binary);arr=arr.reshape(-1,3)[:,[0,2,1]].reshape(-1) if type_=='SCALAR' else arr;data=arr.tobytes();binary.extend(data);views.append({'buffer':0,'byteOffset':offset,'byteLength':len(data),'target':34963 if type_=='SCALAR' else 34962})
   entry={'bufferView':len(views)-1,'componentType':component,'count':len(arr),'type':type_}
   if type_=='VEC3':entry.update(min=arr.min(axis=0).tolist(),max=arr.max(axis=0).tolist())
   refs.append(len(acc));acc.append(entry)
  meshes.append({'name':'SmoothShell' if mat==0 else 'RaisedDragonScales','primitives':[{'attributes':{'POSITION':refs[0],'NORMAL':refs[1]},'indices':refs[2],'material':mat}]})
 materials=[{'name':label,'pbrMetallicRoughness':{'baseColorFactor':[*color,1.0],'metallicFactor':metal,'roughnessFactor':rough}} for label,color,metal,rough in colors]
 j={'asset':{'version':'2.0','generator':'Original dragon egg mesh generator / CC0'},'scene':0,'scenes':[{'nodes':[0,1]}],'nodes':[{'mesh':0,'name':'EggShell'},{'mesh':1,'name':'EggScales'}],'meshes':meshes,'materials':materials,'buffers':[{'byteLength':len(binary)}],'bufferViews':views,'accessors':acc}
 jb=json.dumps(j,separators=(',',':')).encode();jb+=b' '*((-len(jb))%4);binary+=b'\0'*((-len(binary))%4)
 data=struct.pack('<III',0x46546c67,2,12+8+len(jb)+8+len(binary))+struct.pack('<II',len(jb),0x4e4f534a)+jb+struct.pack('<II',len(binary),0x004e4942)+binary
 (OUT/(name+'.glb')).write_bytes(data);print(name,len(data))
glb('DragonEgg_Fire',[('ObsidianShell',[.11,.018,.025],.12,.44),('RubyScales',[.64,.055,.018],.32,.30)])
glb('DragonEgg_Ice',[('DeepBlueShell',[.02,.055,.16],.14,.38),('IceScales',[.15,.65,.86],.26,.28)])
glb('DragonEgg_Emerald',[('DeepJadeShell',[.016,.095,.070],.20,.38),('EmeraldScales',[.05,.42,.22],.35,.29)])
