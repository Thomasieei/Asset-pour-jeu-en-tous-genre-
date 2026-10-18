extends RefCounted
class_name DialogueGuard
# A small model can contradict its profile: reject obvious invented relationships
# and action claims, then label the deterministic fallback instead of hiding it.
static func accepts(text: String, question: String) -> bool:
	var reply := text.strip_edges().to_lower()
	if reply.is_empty() or reply == question.strip_edges().to_lower(): return false
	for invented in ["la mère de","le père de","ta mère","ton père","ta sœur","ton frère","mon fils","ma fille","j'ai construit","j'ai planté","j'ai tué","j'ai récolté"]:
		if invented in reply: return false
	return true
