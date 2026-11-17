# Arise Ville — inventaire à importer depuis l'APK

**Source identifiée :** `AriseVille (5).apk`, fourni par le propriétaire. **28 modèles 3D retrouvés** sous forme de scènes Godot 4.3 compilées (`.scn`) et de textures compilées (`.ctex`). Aucun GLB original n'est directement inclus dans l'APK.

**État GitHub : inventaire + procédure d'extraction seulement.** Les scènes 3D compilées ne sont pas encore copiées dans ce dépôt public : il faut d'abord les convertir, vérifier leurs dépendances et leurs licences. Ne pas les compter parmi les 3 671 modèles d'origine déjà présents et vérifiés dans `packs/`.

## boss (1)

- `igris`

## monstres (4)

- `chaman`
- `goblin`
- `orc`
- `orc_warrior`

## humains (8)

- `hero`
- `hunter`
- `guard`
- `civ_coolman`
- `civ_driver`
- `civ_manplayer`
- `civ_rida`
- `civ_woman`

## armes (5)

- `dague`
- `hache`
- `katana`
- `lame`
- `sl_sword`

## vehicules (2)

- `civil_cars`
- `police_ford`

## villes (3)

- `city`
- `orc_house`
- `warehouse`

## donjons (1)

- `hall`

## decors (1)

- `marsh`

## objets (3)

- `chest_gold`
- `coffre`
- `props`

## Sources supplémentaires disponibles

Deux GLB originaux portant les mêmes noms, reçus séparément de l'APK : `orc_warrior.glb` (~9 327 triangles, 1 animation) et `orc_house.glb` (~103 859 triangles, nécessite un allègement Android). Leur équivalence avec les modèles compilés et les droits de redistribution doivent être contrôlés avant publication.

## Extraction et conversion

1. Utiliser [`scripts/extract_arise_ville.py`](../../scripts/extract_arise_ville.py) avec l'APK d'origine pour extraire les `.scn`, `.ctex` et remaps `.import` sans fichiers de code Android ni musique.
2. Conserver les chemins Godot d'origine et utiliser Godot 4.3 avec `GLTFDocument` pour essayer d'exporter en `.glb`. Le réexport n'est pas encore testé : il peut nécessiter les sources originales.
3. Contrôler le nombre de triangles, le rig, les matériaux, les animations, la licence et les FPS Android. Ne publier dans la banque ouverte que les fichiers dont la redistribution est permise.

Ce dépôt est **une banque d'assets distincte** de tout jeu, notamment de `Legion-d-Ombre`.
