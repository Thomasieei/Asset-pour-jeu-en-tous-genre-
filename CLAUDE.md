# Instructions pour les assistants utilisant cette banque

Lire catalog.json : packs décrit les sources/licences, models les GLB/glTF, assets les images/sons/scènes. Chercher par catégorie et nom, puis utiliser le chemin réel. Ne pas inventer d’asset ni annoncer une disponibilité non vérifiée.

Pour un RPG stylisé propre, privilégier KayKit Adventures/Skeletons, Dungeon Remastered, Forest, Medieval Hexagon, RPG Tools et Resource Bits. Choisir une palette et une échelle cohérentes. Block Bits est réservé aux jeux de construction à blocs. Les mannequins d’animation sont des supports techniques, pas des personnages finaux. Ne pas ajouter de pixel art ni de greybox comme art final.

Interfaces : privilégier les SVG et les PNG d’origine ; inventaire : packs/inventory-icons-3d/PNG, 512x512 transparents. Ne pas agrandir de minuscules rasters sans source vectorielle. Sons dans les packs Kenney audio, 6 scènes VFX dans godot-vfx-presets avec dépendance kenney-particle-pack. Ces scènes sont visuelles ; la logique de dégâts/inventaire appartient au jeu.

Conserver les textures et BIN avec leur modèle, les chemins relatifs et les licences. Les animations KayKit nécessitent un rig Medium/Large compatible. godot_verified signifie import/chargement vérifié, pas FPS, collisions, gameplay ou rendu sur téléphone garanti. Contrôler performances et apparence dans le projet final. Ne copier que les assets nécessaires dans un APK.

Les archives et empreintes sont figées ; ne pas accepter automatiquement une archive modifiée. Préserver les sources CC0 et les rapports quality. Les versions payantes EXTRA/SOURCE et Prototype Bits sont exclues.
