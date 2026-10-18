# Loïc — prototype Godot 4.3 indépendant

Nouveau projet de simulation, sans lien avec Yggdrasil. Cette branche contient une scène Godot autonome qui référence les vrais assets KayKit déjà présents dans cette banque : `Knight.glb` et les packs d'animations medium (à retargeter si nécessaire).

## Démarrage
Ouvrir la **racine de cette branche** avec Godot 4.3, puis lancer `res://loic/scenes/monde_loic.tscn` (F6). Le `project.godot` de cette branche définit cette scène comme entrée par défaut. La branche principale de la banque n'a pas été modifiée.

## Fonctionnel dans cette V0
- Loïc a 24 ans, sa vision du monde, ses traits, besoins, stats, mana, XP/niveaux, inventaire et équipement.
- Il prend des décisions périodiques : explorer, rentrer dormir chez lui si épuisé, manger, fuir/demander de l'aide ou attaquer selon son état.
- Combats **simulés** avec points de vie d'un monstre; XP/loot après victoire, aucun véritable modèle de monstre, hitbox ou navigation.
- Sa position, ses relations, son inventaire et jusqu'à 150 souvenirs sont sauvegardés dans `user://loic_unique_save.json`.
- Dialogues via HTTP vers llama.cpp `127.0.0.1:8765` compatible OpenAI, avec réponse déterministe de secours sans Qwen. Le GGUF joint n'est **pas** embarqué dans Godot : lancer le serveur séparément avec le bundle IA du dépôt.
- Modèle Knight KayKit chargé automatiquement. AnimationPlayer et clips sont découverts si présents sur le personnage ; les packs Rig Medium séparés **ne sont pas encore retargetés** et les actions sans clip ne sont pas animées.

## Limitations honnêtes
C'est un prototype technique et non un jeu complet testé sur Android : environnement en volumes simples, pas de collisions physiques des actions, pas de maison intérieure réellement meublée, pas de monstres 3D, pas de synchronisation multijoueur. Le sommeil est autorisé uniquement au point maison. Le modèle linguistique converse mais ne commande pas librement les actions du moteur. Les comportements déterministes assurent les règles; les décisions du LLM nécessiteront un contrat JSON contrôlé. Pas d'apprentissage des poids du modèle: la mémoire est persistée en données.

## Provenance
- Modèle: `packs/kaykit-character-pack-adventures-1.0/addons/kaykit_character_pack_adventures/Characters/gltf/Knight.glb`
- Clips disponibles: `packs/kaykit-character-animations-1.1/Animations/gltf/Rig_Medium`
- Runtime IA séparé: `ai/royaume-vivant`
