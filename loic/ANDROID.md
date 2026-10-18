# Loïc sur téléphone — V0.2 locale

Cette version contient Qwen3 0.6B Q4_K_M et un moteur llama.cpp CPU natif arm64.
Elle fonctionne **sans ordinateur, compte, clé API ni accès Internet**.
L’APK ne demande aucune permission réseau. Le modèle n’est pas téléchargé après installation.

## Jouer

1. Installer l’APK signé, puis l’ouvrir en mode paysage.
2. Choisir le nom et l’apparence de son habitant : chevalier, mage, éclaireur ou barbare.
3. Déplacer son personnage avec le cercle tactile en bas à gauche.
4. Ouvrir **Discuter**, choisir Loïc, Élise, Garen ou Monde, puis écrire son message.
5. Pour un habitant éloigné, utiliser **Rejoindre** ; les échanges demandent une distance de 7 unités au maximum.
6. **Mon personnage** permet de changer son nom et son apparence. **Gestion** ouvre les outils du village.

Le premier démarrage copie et vérifie les poids dans l’espace privé de l’application,
puis charge l’IA. L’interface indique cette préparation ; ensuite elle affiche
« Qwen local prêt ». La copie nécessite environ 397 Mo supplémentaires au fichier installé.
Prévoir environ 1,5 Go libres en comptant téléchargement, installation et copie locale.
L’application partage un seul modèle entre les habitants et le gestionnaire, avec une
file de calcul sur un autre fil d’exécution. Les réponses peuvent prendre plusieurs
secondes et dépendent du téléphone. Les décisions automatiques sont espacées pour
limiter la concurrence avec les conversations.

Les profils, positions et conversations sont sauvegardés sur le téléphone. Les anciens
souvenirs ne modifient pas les poids du modèle. Les réponses de secours portent le
préfixe « Réponse simple ». Les demandes simples au Monde, comme planter un arbre,
sont également reconnues à règles si l’inférence échoue.

## Vérification réelle et limites

- APK arm64 construit, aligné et signé ; signature vérifiée par apksigner.
- Présence du GGUF, de l’extension Android et de ses dépendances vérifiée dans l’APK.
- SHA-256 du modèle extrait de l’APK identique aux poids d’origine.
- 34 contrôles de simulation ; 16 contrôles du personnage et des conversations.
- 7 contrôles de l’extension native **exécutés sur Linux**, avec les mêmes sources
  llama.cpp et le même modèle. Loïc, Élise et Garen ont répondu sans serveur HTTP ;
  le gestionnaire a créé un vrai travail à partir d’une intention structurée.
- **L’APK n’a pas été installé ni exécuté sur un appareil Android pendant ces tests.**
  Le chargement Android, la vitesse, la chauffe et la compatibilité de l’appareil restent à vérifier.
- Le modèle de 0,6 milliard de paramètres peut répéter des phrases ou donner des réponses
  peu cohérentes. Il ne voit pas les pixels et ne programme pas de nouvelles fonctions.
- Le combat reste une simulation. Les travaux sont limités aux outils prévus ; le monde
  ne continue pas d’évoluer une fois l’application fermée.

## Sources et reconstruction

`loic/native/src/loic_local_ai.cpp` fournit la GDExtension. Les poids et bibliothèques
compilées sont exclus de Git pour conserver des sources légères. Le fichier
`.gdextension.example` est copié en `.gdextension` lors de la compilation.
Le projet source reste ouvrable sur ordinateur en mode règles ou serveur HTTP ;
l’extension est nécessaire pour le mode local natif.

Avec Python 3.11+, CMake, Ninja, SCons, GCC, le NDK Android r26d et Godot 4.3 :

```sh
python3 loic/build/build_native.py --ndk /chemin/android-ndk-r26d --work /tmp/loic-build
python3 loic/build/prepare_android.py /tmp/loic-android-project
```

Le script vérifie les commits des deux bibliothèques et les empreintes des poids.
La préparation sélectionne 14 modèles utiles, leurs dépendances et licences, plutôt
que d’embarquer les 3 671 modèles de la banque. Ajouter ensuite un preset Android Godot
arm64, les templates officiels 4.3 et un keystore de test pour exporter le projet préparé.
Le preset de cette version est conservé dans `loic/build/export_presets.cfg.example` ;
remplacer les chemins marqués `REPLACE_...` par ceux du poste de compilation.

Sources figées : llama.cpp b11598 / f441d2d9db68410f78b9e937efe479049f458044 ;
godot-cpp 4.3 / fbbf9ec4efd8f1055d00edb8d926eef8ba4c2cce. Les licences MIT et
Apache 2.0 se trouvent dans `loic/native/licenses/`.
