#!/usr/bin/env python3
"""Build the pinned native CPU backend for Godot 4.3 (Linux and Android arm64)."""
import argparse,hashlib,os,shutil,subprocess,sys,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PINS={'godot-cpp':('https://github.com/godotengine/godot-cpp.git','godot-4.3-stable','fbbf9ec4efd8f1055d00edb8d926eef8ba4c2cce'),'llama.cpp':('https://github.com/ggml-org/llama.cpp.git','b11598','f441d2d9db68410f78b9e937efe479049f458044')}
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--ndk',type=Path,required=True,help='Extracted Android NDK r26d directory')
parser.add_argument('--work',type=Path,required=True)
parser.add_argument('--jobs',type=int,default=4)
a=parser.parse_args();work=a.work.resolve();work.mkdir(parents=True,exist_ok=True)

def run(args,**kwargs):subprocess.run([str(x) for x in args],check=True,**kwargs)
def digest(path):
 with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()
for name,(url,tag,sha) in PINS.items():
 dest=work/name
 if not dest.exists():run(['git','clone','--depth','1','--branch',tag,url,dest])
 if subprocess.check_output(['git','-C',str(dest),'rev-parse','HEAD']).decode().strip()!=sha:raise RuntimeError('Unexpected source commit: '+name)
base=['-DCMAKE_BUILD_TYPE=Release','-DCMAKE_POSITION_INDEPENDENT_CODE=ON','-DBUILD_SHARED_LIBS=OFF','-DGGML_NATIVE=OFF','-DGGML_OPENMP=OFF','-DGGML_BACKEND_DL=OFF','-DGGML_LLAMAFILE=OFF','-DLLAMA_CURL=OFF','-DLLAMA_BUILD_TESTS=OFF','-DLLAMA_BUILD_EXAMPLES=OFF','-DLLAMA_BUILD_TOOLS=OFF','-DLLAMA_BUILD_SERVER=OFF','-DLLAMA_BUILD_COMMON=OFF']
sdk=work/'sdk';(sdk/'ndk').mkdir(parents=True,exist_ok=True)
link=sdk/'ndk/23.2.8568313'
if not link.exists():link.symlink_to(a.ndk.resolve(),target_is_directory=True)
for platform,arch in [('linux','x86_64'),('android','arm64')]:
 build=work/('llama-'+platform)
 flags=[] if platform=='linux' else ['-DCMAKE_TOOLCHAIN_FILE='+str(a.ndk.resolve()/'build/cmake/android.toolchain.cmake'),'-DANDROID_ABI=arm64-v8a','-DANDROID_PLATFORM=android-24','-DANDROID_STL=c++_static','-DGGML_CPU_ARM_ARCH=armv8-a']
 run(['cmake','-S',work/'llama.cpp','-B',build,'-G','Ninja']+base+flags)
 # Build only the library; the upstream app target is unnecessary.
 run(['cmake','--build',build,'--target','llama','-j',a.jobs])
 env=os.environ.copy();env.update({'GODOT_CPP_SOURCE':str(work/'godot-cpp'),'LLAMA_SOURCE':str(work/'llama.cpp'),'LLAMA_BUILD':str(build),'ANDROID_HOME':str(sdk)})
 run(['scons','platform='+platform,'arch='+arch,'target=template_release','android_api_level=24','build_profile=build_profile.json','-j'+str(a.jobs)],cwd=ROOT/'loic/native',env=env)
shutil.copy(ROOT/'loic/native/loic_local_ai.gdextension.example',ROOT/'loic/native/loic_local_ai.gdextension')
model=ROOT/'loic/native/models/Qwen3-0.6B-Q4_K_M.gguf'
if not model.exists():
 archive=work/'qwen-bundle.zip'
 if not archive.exists():
  with urllib.request.urlopen('https://github.com/Thomasieei/Asset-pour-jeu-en-tous-genre-/releases/download/royaume-vivant-ia-v1/Royaume-Vivant-IA-Locale.zip',timeout=120) as src,archive.open('wb') as dst:shutil.copyfileobj(src,dst)
 if digest(archive)!='9c9828193722b3e17275df5222c85bef1c1bc3fe2f1bd92fa7716faca1319399':raise RuntimeError('Bundle SHA mismatch')
 model.parent.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(archive) as z,model.open('wb') as out:
  with z.open('Royaume-Vivant-IA-Locale/Qwen3-0.6B-Q4_K_M-requantized.gguf') as src:shutil.copyfileobj(src,out)
if digest(model)!='15e434d8ddf0af38fe3f7003af6ce6eac4edada6df34324aa45979f9cc79f02e':raise RuntimeError('Model SHA mismatch')
print('Native libraries and verified model ready')
