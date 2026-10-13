#!/usr/bin/env python3
"""Shared local LLM, Linux x86_64. Never exposes the server beyond localhost."""
import pathlib,subprocess,os,sys
base=pathlib.Path(__file__).resolve().parent
server=base/'runtime'/'llama-server'
if not server.is_file():sys.exit('Runtime Linux manquant. Consulter README.md.')
env=os.environ.copy()
env['LD_LIBRARY_PATH']=str(base/'runtime')+':'+env.get('LD_LIBRARY_PATH','')
subprocess.run([str(server),'-m',str(base/'Qwen3-0.6B-Q4_K_M-requantized.gguf'),'-c','2048','-t','4','--host','127.0.0.1','--port','8765','--jinja','-ngl','0'],env=env,check=True)
