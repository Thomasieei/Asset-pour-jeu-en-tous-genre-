# Nouvelle couche : Conscience du Monde

Cette branche Godot 4.3 est un prototype de simulation indépendante d'Yggdrasil, vivant directement au sein de la banque d'assets complète.

## Banque d'assets
Les 55 packs existants et les 3 671 modèles GLB/glTF restent accessibles depuis le projet via `res://packs/` et `catalog.json`. **Ils ne sont pas tous instanciés ni chargés en mémoire en même temps** (ce serait contre-productif pour les performances et les temps d'import). Les chemins actuellement sélectionnés pour l'environnement sont des vrais modèles KayKit : arbres de Forest Free, maison, marché, moulin et forge de Medieval Hexagon. Les cultures sont une géométrie générée en attendant une sélection de modèles agricoles cohérents.

## Deux IA distinctes
- `LoicBrain` : intentions personnelles de Loïc (se déplacer, dialoguer, combattre, demander de l'aide).
- `WorldConductor` : proposition de travaux de développement du monde, indépendante du comportement individuel de Loïc. Un ordonnanceur attribue les travaux à Élise, Garen et Loïc, applique les coûts en bois/pierre, marque le chantier terminé après un délai et place l'élément visuel dans le monde.
- Le modèle Qwen est **optionnel et partagé** via `http://127.0.0.1:8765/v1/chat/completions` : si le serveur est absent ou produit une réponse invalide, les règles déterministes prennent le relais.
- La conscience du monde n'est pas une conscience phénoménale ; c'est un agent de planification et de coordination.

## Sauvegardes
`user://world_conductor.json` contient les ordres, ressources, constructions, chantiers en cours et cycle du monde. Chaque rechargement reconstruit les visuels.
`user://loic_unique_save.json` et `user://loic_social.json` conservent les expériences de Loïc et sa réputation.

## Limites
Le chantier est une simulation de commande et de délai : les ouvriers n'ont pas encore d'animation de construction ou de navigation jusqu'au chantier; les champs n'ont pas encore une croissance agricole temporelle; le monde ne poursuit pas son évolution lorsque le programme est éteint. Le terrain est encore plat. Le code doit être validé par le workflow Godot 4.3 (et en appareil Android). Aucun moteur Qwen Android embarqué n'est livré.
