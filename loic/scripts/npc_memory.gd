extends RefCounted
class_name NpcMemory
const MAX_FACTS := 60
static func remember(memories: Dictionary, person: String, text: String, important: bool = false) -> void:
	if not memories.has(person): memories[person] = []
	var lowered := text.to_lower()
	var meaningful := important
	for prefix in ["je m'appelle","j'aime","je préfère","je déteste","je veux","mon objectif","mon rêve","je promets","je suis"]:
		if prefix in lowered: meaningful = true
	if not meaningful: return
	for fact in memories[person]:
		if fact.text == text.left(180): return
	memories[person].append({"text":text.left(180),"time":Time.get_unix_time_from_system(),"important":important})
	while memories[person].size()>MAX_FACTS: memories[person].pop_front()

static func recall(memories: Dictionary, person: String, question: String, limit: int = 4) -> Array:
	var words := question.to_lower().replace("'"," ").replace("?"," ").split(" ",false)
	var ranked: Array = []
	for fact in memories.get(person,[]):
		var score := 1.0 if fact.get("important",false) else 0.0
		for word in words:
			if word.length()>3 and word not in ["avec","dans","pour","quels","quelle","comment","pourquoi","est-ce"] and word in str(fact.text).to_lower(): score += 3
		score += float(fact.get("time",0))*0.000000001
		ranked.append({"score":score,"text":fact.text})
	ranked.sort_custom(func(a: Dictionary,b: Dictionary): return a.score>b.score)
	var result: Array = []
	for item in ranked.slice(0,limit): result.append(item.text)
	return result
