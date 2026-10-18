# Loïc — Aurore — Android V0.4

Cette version reprend la composition de la maquette : caméra en perspective rapprochée derrière le personnage, village et moulin à gauche, rivière, pont de pierre, forêt à droite et château à l’horizon. Les modèles du dépôt restent plus simples que l’illustration générée ; le rendu n’est pas une copie graphique exacte de cette image.

## Installer et jouer

Installer `Loic-Monde-Vivant-Android.apk` sur un téléphone Android arm64, puis ouvrir **Loïc – Aurore** en paysage. Cette application utilise le paquet `fr.thomas.loicmondevivant.aurore`. Elle s’installe à côté de V0.3, sans toucher à ses sauvegardes. La signature précédente n’étant plus disponible dans l’environnement de compilation, V0.4 possède un nouveau certificat de développement et son propre monde. Il ne faut pas désinstaller V0.3 pour installer Aurore.

- Joystick en bas à gauche : déplacer le personnage.
- Cercles à droite : épée, saut, accroupissement et conversation.
- Message au centre en bas : choisir l’interlocuteur, écrire puis toucher la flèche bleue. L’envoi à distance est autorisé. La petite flèche près du nom permet de rejoindre l’habitant.
- Cœur : personnaliser son nom et son apparence.
- Minicarte : position du joueur, rivière, bâtiments et habitants ; toucher pour ouvrir les voyages du monde.
- Sur ordinateur : ZQSD/WASD ou flèches, molette pour la distance et clic droit glissé pour tourner la caméra.

La saisie remonte quand le clavier virtuel apparaît. Les messages et les réponses restent affichés et sont sauvegardés. Une erreur du moteur IA termine la requête et débloque le bouton ; après 75 secondes, une réponse simple explicitement marquée remplace l’attente.

## IA embarquée

Qwen3 0.6B Q4_K_M et llama.cpp CPU sont inclus dans l’APK. Aucun ordinateur, compte, clé API ou accès Internet n’est nécessaire. L’APK ne demande pas la permission Internet. Le premier démarrage copie et vérifie environ 397 Mo de poids dans l’espace privé de l’application. Prévoir environ 1,5 Go libres en comptant téléchargement, installation et copie.

Le modèle est partagé entre dialogues, habitants, créatures et gestionnaire. Les conversations sont prioritaires. Une courte présentation du personnage dans le contexte réduit les confusions de rôle ; les échos de la question et les confusions explicites avec le nom du joueur sont refusés. Le modèle reste petit et ses réponses peuvent être incohérentes. Les secours portent le préfixe `[Réponse simple]`. Les personnages simulent des personnalités et des souvenirs, sans preuve de conscience subjective. Ils utilisent les outils du jeu et ne réécrivent pas les scripts.

## Vérifications

Les rapports sont dans `loic/tests/` : simulation du village sur trente minutes, personnage, monde et tests rendus du HUD. Ces derniers injectent des événements de souris et de toucher pour vérifier les vrais boutons, le joystick, le focus de saisie, la présence visible des messages, la réponse native de Qwen et la remontée du panneau au-dessus d’un clavier simulé. Deux formats paysage sont contrôlés.

Ces tests ont été exécutés avec Godot 4.3 sur Linux. L’APK est construit, aligné et signé, et son modèle et ses bibliothèques sont vérifiés. **Cette APK n’a pas été installée ni exécutée sur un téléphone Android ici.** Le clavier réel, le chargement natif, la chauffe et les performances du téléphone restent donc à confirmer.

Les habitants utilisent une grille de chemins qui évite les bâtiments et traverse la rivière par le pont. Le monde s’arrête lorsque l’application est fermée. Les voyages lointains et les combats restent ceux du prototype précédent. Aucun multijoueur n’a été ajouté.

## Reconstruction

Les poids et bibliothèques compilées restent hors Git. Les licences sont conservées. Avec Python, CMake, Ninja, SCons, GCC, NDK r26d et Godot 4.3 :

```sh
python3 loic/build/build_native.py --ndk /chemin/android-ndk-r26d --work /tmp/loic-build
python3 loic/build/prepare_android.py /tmp/loic-android-project
```

Le projet Android sélectionne 39 modèles de la banque et copie leurs dépendances externes, y compris celles des GLB, ainsi que les licences. Utiliser ensuite `loic/build/export_presets.cfg.example`, les templates officiels Godot 4.3, un SDK Android 34 et le keystore de développement Aurore pour exporter. Le certificat Aurore devra être conservé pour que les prochaines versions puissent mettre cette application à jour.
