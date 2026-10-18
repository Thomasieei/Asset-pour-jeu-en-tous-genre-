extends RefCounted
class_name DialogueGuard
# A small model can contradict its profile: reject obvious invented relationships
# and action claims, then label the deterministic fallback instead of hiding it.
static func accepts(text: String, question: String, speaker: String = "", player_name: String = "") -> bool:
	var reply := text.strip_edges().to_lower()
	if reply.is_empty() or reply == question.strip_edges().to_lower(): return false
	if not speaker.is_empty() and not player_name.is_empty() and speaker.to_lower()!=player_name.to_lower():
		for prefix in ["je m'appelle ","mon nom est ","je suis "]:
			if prefix+player_name.to_lower() in reply: return false
	for invented in ["la mère de","le père de","ta mère","ton père","ta sœur","ton frère","mon fils","ma fille","j'ai construit","j'ai planté","j'ai tué","j'ai récolté"]:
		if invented in reply: return false
	return true
