extends Node
class_name LoicSocial

signal event(message: String)
var acquaintances := {
	"Elise":{"name":"Élise","role":"guérisseuse","trust":18,"affection":15,"last_topic":"soins"},
	"Garen":{"name":"Garen","role":"garde","trust":10,"affection":4,"last_topic":"patrouille"}
}
var intentions: Array[String] = ["saluer","aider","se_lier","demander_aide","refuser"]

func converse(agent: Node3D, person: String, intent: String) -> String:
	if not acquaintances.has(person):
		return "Je ne connais pas encore cette personne."
	if intent not in intentions:
		return "Je ne sais pas encore quoi lui dire."
	var npc: Dictionary = acquaintances[person]
	var text := ""
	match intent:
		"saluer":
			npc.trust = mini(100,int(npc.trust)+1)
			text = "Bonjour %s, quelle belle journée !" % npc.name
		"aider":
			if agent.stats.endurance < 15:
				return "J'aimerais aider, mais je suis épuisé."
			agent.stats.endurance -= 10
			npc.trust = mini(100,int(npc.trust)+5)
			npc.affection = mini(100,int(npc.affection)+2)
			text = "Je vais t'aider, %s. Personne ne devrait être seul." % npc.name
		"se_lier":
			npc.affection = mini(100,int(npc.affection)+3)
			text = "Dis-moi, %s, quel rêve aimerais-tu réaliser ?" % npc.name
		"demander_aide":
			if int(npc.trust) >= 15:
				agent.stats.vie = minf(agent.stats.vie_max,agent.stats.vie+12)
				npc.trust = maxi(0,int(npc.trust)-1)
				text = "Merci, %s. Tu m'as réellement aidé." % npc.name
			else:
				text = "%s ne me fait pas encore assez confiance pour m'aider." % npc.name
		"refuser":
			npc.trust = maxi(-100,int(npc.trust)-2)
			text = "Je suis désolé %s, j'ai mes propres priorités." % npc.name
	npc.last_topic = intent
	acquaintances[person] = npc
	agent.relations[person] = npc.trust
	agent.souvenir(text,2)
	event.emit(text)
	return text
