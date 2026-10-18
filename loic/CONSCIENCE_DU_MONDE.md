# Gestion et perception du monde — V1

La scène d’entrée Godot référence directement Loïc et le gestionnaire.

| Élément | Rôle réel |
|---|---|
| `asset_registry.gd` | Recherche dans catalog.json, cache de scènes, normalisation de taille |
| `world_eyes.gd` | Objets proches, distance, visibilité et occultation par rayons physiques |
| `loic_brain.gd` | Intentions personnelles Qwen en JSON Schema ; validation par LoicAgent |
| `world_conductor.gd` | État global, décisions Qwen/règles, budgets, placement, croissance et sauvegarde |
| `world_worker.gd` | Habitants visibles, trajet, travail, fatigue, repos et perception locale |
| `lancer_loic.py` | Téléchargement vérifié du bundle existant, démarrage IA + Godot sur Linux x86_64 |

Le monde propose les outils : planter un arbre, cultiver un champ, construire maison,
atelier, marché ou moulin, récolter, ramasser du bois et extraire de la pierre.
Une proposition refusée ne modifie pas les stocks. Les coûts sont réservés au lancement ;
la file limitée à deux travaux ne progresse que par le travail des habitants.
Après interruption, les travaux persistés sont réattribués avec leur progression.
Les anciens enregistrements V0 sont migrés vers des identifiants stables et des durées en secondes.

La boucle de secours vise 18 arbres, 3 champs, 2 maisons et les services, puis entretient
les réserves. La maturité croît en environ 70 secondes ; une récolte réinitialise la plante.
La population consomme trois unités de nourriture par cycle de 12 secondes.
Les arbres ne donnent plus de bois au moment de la plantation.
La pause arrête les ouvriers et la croissance ; elle ignore une réponse IA arrivée en retard.
Loïc conserve ses besoins et ses décisions lorsque le gestionnaire est en pause.

Sauvegardes : `user://world_conductor.json`, `user://loic_unique_save.json`,
`user://loic_social.json`. Aucun écoulement du temps hors application.

Les yeux fournissent un relevé géométrique au modèle de texte. Le gestionnaire n’est pas
un modèle multimodal, ne réécrit pas le code et n’a pas de conscience subjective démontrée.
Les travaux de Loïc, la navigation physique complète, les combats physiques et l’inférence
native Android restent à développer. Lire README.md pour démarrage, commandes et limites.
