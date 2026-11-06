# Légion d'Ombre — RPG 3D incrémental (Godot 4.3, Android)

Couche 1 (tranche jouable) : village d'Havrebrume + Plaine des Tertres, combat, éveil d'ombres,
armée qui combat à vos côtés, forge, boss avec attaque télégraphiée, objectifs guidés, sauvegarde.

## Tester sur téléphone
Chaque `git push` touchant `game/` lance le workflow **Jeu Android - Légion d'Ombre** :
import → test automatique (unitaires + scénario de jeu) → APK. L'APK est publié dans
**Releases** (pré-version `jeu-v0.1.N`) : l'ouvrir depuis le téléphone et installer.

## Contrôles
- Joystick gauche (flottant) · glisser à droite = caméra
- Épée = combo 3 coups · Esquive (invulnérable pendant le roulé) · Armée = invoquer / rappeler
- ÉVEILLER apparaît près d'une dépouille, avec la vraie probabilité de réussite
- Bouton vert contextuel : parler aux PNJ, Forge, Caserne (collection d'ombres), Chapelle
- Clavier (PC) : ZQSD/WASD, J attaque, K/Espace esquive, E interagir, F éveiller, R armée

## Architecture
- `scripts/core` : `Big` (grands nombres, format FR), `Data` (espèces), `Bonus` (moteur de bonus
  centralisé), `Combat` (formules pures), `Game` (état + sauvegarde JSON atomique), `Sfx`, `Fx`
- `scripts/world/world_builder.gd` lit `data/world.json`, généré et **validé** par
  `tools/jeu/build_world.py` (pas de chevauchement, portes reliées aux routes, arbres hors des routes,
  apparitions dans la zone jouable). `tools/jeu/preview_world.py top|spawn|hunt` en fait un rendu.
- `scripts/actors` : joueur, ennemis/boss (machine à états + laisse de camp), ombres alliées,
  armée centralisée, PNJ, projectiles
- `scripts/ui` : HUD, contrôles multi-touch, panneaux (Ombres, Forge, Bonus, Réglages), portraits 3D

## Optimisations mobile
Animations inutiles retirées des GLB (21 Mo → 5 Mo de personnages), végétation en MultiMesh
découpée en cellules de 40 m (culling) avec distances de visibilité, ombres portées seulement à
proximité, textures de particules réduites à 128 px, rendu Compatibilité, compression ETC2/ASTC,
APK arm64 uniquement, effets en pool (aucune allocation pendant le combat).

## Licences
Assets CC0 (KayKit, Kenney) — voir les licences dans `packs/` à la racine du dépôt.
