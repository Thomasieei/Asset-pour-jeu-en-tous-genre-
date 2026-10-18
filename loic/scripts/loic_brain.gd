extends Node
class_name LoicBrain

signal decision(action: String, motive: String, source: String)
var http: HTTPRequest
var pending := false
var elapsed := 0.0
var enabled := true
const ENDPOINT := "http://127.0.0.1:8765/v1/chat/completions"
const VALID := ["observer","marcher","courir","esquiver","attaquer","aider","demander_aide","rentrer","dormir","parler","equiper","se_reposer"]

func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = 10
	add_child(http)
	http.request_completed.connect(_received)

func ponder(agent: Node3D, situation: Dictionary) -> void:
	if pending or not enabled:
		return
	# Le modèle ne contrôle que des intentions limitées, jamais le code moteur.
	var context := {
		"personne": "Loïc, 24 ans, chevalier convaincu de vivre dans un univers parfait",
		"traits":agent.traits,
		"etat":agent.stats,
		"besoins":agent.besoins,
		"action_actuelle":agent.action,
		"danger":agent.ennemi_proche,
		"distance_maison":agent.position.distance_to(agent.maison),
		"relations":agent.relations,
		"derniers_souvenirs":agent.souvenirs.slice(maxi(0,agent.souvenirs.size()-8)),
		"alentours":situation
	}
	var system := "Tu es le moteur de décision de Loïc, un habitant libre dans un jeu fantasy. "
	system += "Choisis une action cohérente et un motif EN FRANÇAIS. Tu peux préférer fuir, demander de l'aide, aider, parler ou explorer; ne choisis pas toujours combattre. "
	system += "Une action est une intention, non son exécution. Le moteur appliquera sécurité, capacités et contraintes. "
	system += "Réponds UNIQUEMENT en JSON {\"action\":\"...\",\"motive\":\"...\"}. Actions autorisées: " + ", ".join(VALID) + ". /no_think"
	var request_body := {
		"model":"local",
		"messages":[{"role":"system","content":system},{"role":"user","content":JSON.stringify(context)+" /no_think"}],
		"temperature":0.6, "max_tokens":110,
		"chat_template_kwargs":{"enable_thinking":false}
	}
	pending = true
	var err := http.request(ENDPOINT,["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(request_body))
	if err != OK:
		pending = false

func _received(result: int, code: int, _headers: PackedStringArray, payload: PackedByteArray) -> void:
	pending = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data = JSON.parse_string(payload.get_string_from_utf8())
	if not (data is Dictionary):
		return
	var choices = data.get("choices",[])
	if not (choices is Array) or choices.is_empty():
		return
	var msg = choices[0]
	if not (msg is Dictionary):
		return
	var parsed = JSON.parse_string(str(msg.get("message",{}).get("content","")))
	if not (parsed is Dictionary):
		return
	var proposed := str(parsed.get("action",""))
	var motive := str(parsed.get("motive","")).left(220)
	if proposed in VALID:
		decision.emit(proposed,motive,"Qwen")
