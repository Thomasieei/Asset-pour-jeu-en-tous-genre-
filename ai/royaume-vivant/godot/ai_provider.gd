class_name KingdomAIProvider
extends Node
signal answer(intent: Dictionary, source: String)
signal npc_answer(intent: Dictionary)
var request_kind := "order"
var pending_npc := ""
var http := HTTPRequest.new()
var enabled := false
var busy := false
var last_request := -100.0
var pending_text := ""
var endpoint := "http://127.0.0.1:8765/v1/chat/completions"
var status := "Règles locales — aucun modèle embarqué Android"
const SCHEMA = {"type":"object","properties":{"action":{"type":"string","enum":["build_house","build_wall","build_road","prioritize_food","patrol","unknown"]},"reason":{"type":"string"}},"required":["action","reason"],"additionalProperties":false}
func _ready():
	add_child(http);http.timeout=15;http.body_size_limit=65536
	http.request_completed.connect(_completed)
func interpret(text: String, context: Dictionary):
	text=text.strip_edges().left(400)
	if text.is_empty():answer.emit({"intent":"unknown"},"règles");return
	if not enabled or busy or Time.get_ticks_msec()/1000.0-last_request<5:
		answer.emit(rule_based(text),"règles");return
	busy=true;request_kind="order";pending_text=text;last_request=Time.get_ticks_msec()/1000.0
	var body := {"messages":[{"role":"system","content":"Classify the French sovereign order. Actions: maison = build_house; muraille or palissade = build_wall; route or chemin = build_road; nourriture or cultures = prioritize_food; patrouille = patrol. Otherwise unknown. Return action and a short reason as JSON. Current simulation facts: "+JSON.stringify(context)+" /no_think"},{"role":"user","content":text+" /no_think"}],"temperature":0,"max_tokens":160,"chat_template_kwargs":{"enable_thinking":false},"response_format":{"type":"json_schema","json_schema":{"name":"intent","strict":true,"schema":SCHEMA}}}
	var err := http.request(endpoint,["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(body))
	if err!=OK:busy=false;status="LLM indisponible : règles actives";answer.emit(rule_based(text),"règles")
func _completed(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray):
	busy=false
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if result==HTTPRequest.RESULT_SUCCESS and code==200 and parsed is Dictionary and parsed.has("choices"):
		var out = JSON.parse_string(str(parsed.choices[0].message.content))
		if out is Dictionary:
			if request_kind=="npc":
				if out.get("npc_id","")==pending_npc and out.get("intent","") in ["continue_work","request_rest","request_supplies"]:
					npc_answer.emit(out);status="Qwen local : profil "+pending_npc+" évalué"
				return
			out=normalize_order(out)
			var expected:=rule_based(pending_text)
			if expected.intent!="unknown" and (out.get("intent","")!=expected.intent or out.get("npc_id","")!=expected.npc_id or out.get("building_type","")!=expected.building_type):
				status="Intention Qwen incohérente : règles actives";answer.emit(expected,"règles après rejet Qwen");return
			status="Qwen local partagé — réponse reçue";answer.emit(out,"Qwen local");return
	status="LLM indisponible ou réponse invalide : règles actives"
	if request_kind=="order":answer.emit(rule_based(pending_text),"règles")
func rule_based(text: String) -> Dictionary:
	var t := text.to_lower()
	if "nourri" in t or "champ" in t or "manger" in t:return {"npc_id":"mira","intent":"food","building_type":"none","reason":"demande_souverain"}
	if "patrou" in t or "garde" in t:return {"npc_id":"kael","intent":"patrol","building_type":"none","reason":"demande_souverain"}
	for pair in [["maison","house"],["palissade","wall"],["muraille","wall"],["route","road"],["chemin","road"]]:
		if pair[0] in t:return {"npc_id":"aldric","intent":"build","building_type":pair[1],"reason":"demande_souverain"}
	return {"npc_id":"soren","intent":"unknown","building_type":"none","reason":"instruction_non_comprise"}
func validate(intent: Dictionary, sim: KingdomSimulation) -> bool:
	if not sim.npcs.has(str(intent.get("npc_id",""))):return false
	var kind := str(intent.get("intent",""))
	if kind=="build":return intent.npc_id=="aldric" and sim.buildings.has(str(intent.get("building_type","")))
	if kind=="food":return intent.npc_id=="mira" and intent.get("building_type","")=="none"
	if kind=="patrol":return intent.npc_id=="kael" and intent.get("building_type","")=="none"
	return false

func evaluate_npc(n: Dictionary, stocks: Dictionary):
	if not enabled or busy:return
	if Time.get_ticks_msec()/1000.0-last_request<5:return
	request_kind="npc";pending_npc=n.id;busy=true;last_request=Time.get_ticks_msec()/1000.0
	var schema:={"type":"object","properties":{"npc_id":{"type":"string","enum":[n.id]},"intent":{"type":"string","enum":["continue_work","request_rest","request_supplies"]},"reason":{"type":"string"}},"required":["npc_id","intent","reason"],"additionalProperties":false}
	var profile:={"id":n.id,"name":n.name,"profession":n.profession,"traits":n.traits,"ambition":n.ambition,"energy":n.energy,"hunger":n.hunger,"morale":n.morale,"task":n.task,"memories":n.memories.slice(maxi(0,n.memories.size()-4)),"stocks":stocks}
	var body:={"messages":[{"role":"system","content":"You advise a village worker using actual facts. Choose continue_work for energy >= 35 and food >= 25 and ore >= 8. Choose request_rest only for energy < 35. Choose request_supplies only if food < 25 or ore < 8. Example healthy worker: continue_work. Example tired worker: request_rest. Use the actual npc_id. JSON only. /no_think"},{"role":"user","content":JSON.stringify(profile)+" /no_think"}],"temperature":0,"max_tokens":120,"chat_template_kwargs":{"enable_thinking":false},"response_format":{"type":"json_schema","json_schema":{"name":"npc_intent","strict":true,"schema":schema}}}
	var err:=http.request(endpoint,["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(body))
	if err!=OK:busy=false;status="LLM indisponible : simulation autonome maintenue"

func normalize_order(out: Dictionary)->Dictionary:
	var actions:={"build_house":["aldric","build","house"],"build_wall":["aldric","build","wall"],"build_road":["aldric","build","road"],"prioritize_food":["mira","food","none"],"patrol":["kael","patrol","none"],"unknown":["soren","unknown","none"]}
	var triple: Array=actions.get(str(out.get("action","unknown")),actions.unknown)
	return {"npc_id":triple[0],"intent":triple[1],"building_type":triple[2],"reason":str(out.get("reason","")).left(240)}
