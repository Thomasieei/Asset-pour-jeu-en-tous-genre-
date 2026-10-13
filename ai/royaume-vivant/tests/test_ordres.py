import urllib.request,json,time,pathlib
schema={'type':'object','properties':{'action':{'type':'string','enum':['build_house','build_wall','build_road','prioritize_food','patrol','unknown']},'reason':{'type':'string'}},'required':['action','reason'],'additionalProperties':False}
results=[]
for text in ['Construisez une maison pour notre nouvelle habitante.','Il nous faut davantage de nourriture.','Construisez une palissade près du pont.','Faites une route entre la forge et la mine.','Envoie Kael patrouiller vers les gobelins.']:
 data={'model':'qwen','messages':[{'role':'system','content':'Classify the French sovereign order. Actions: maison = build_house; muraille or palissade = build_wall; route or chemin = build_road; nourriture or cultures = prioritize_food; patrouille = patrol. Otherwise unknown. Return action and a short reason as JSON. /no_think'},{'role':'user','content':text+' /no_think'}],'temperature':0,'max_tokens':160,'chat_template_kwargs':{'enable_thinking':False},'response_format':{'type':'json_schema','json_schema':{'name':'intent','strict':True,'schema':schema}}}
 t=time.monotonic()
 try:
  req=urllib.request.Request('http://127.0.0.1:8765/v1/chat/completions',json.dumps(data).encode(),{'Content-Type':'application/json'})
  j=json.load(urllib.request.urlopen(req,timeout=45));r={'input':text,'seconds':time.monotonic()-t,'output':j['choices'][0]['message']['content'],'timings':j.get('timings',{})};print(r,flush=True);results.append(r)
 except Exception as e:results.append({'input':text,'error':str(e)})
(pathlib.Path(__file__).resolve().parent/'resultats_ordres.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
