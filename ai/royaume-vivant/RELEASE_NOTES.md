Vrais poids Qwen3 0.6B Q4_K_M, obtenus par requantification des poids Q8_0 officiels et vérifiés par SHA-256. Runtime llama.cpp b11598 Linux x86_64, lanceur, licences Apache 2.0 / MIT et résultats des tests inclus.

Les cinq ordres français testés sont reconnus. Neuf des dix profils sains reçoivent l’intention attendue ; Nessa et deux cas de besoins ont échoué. Les règles du jeu doivent conserver le contrôle des mutations. Aucun réentraînement.

Ce pack est réellement exécutable sur Linux x86_64. Il n’est pas un plugin natif Android, et les dialogues libres ne sont pas intégrés. Le jeu Android n’est pas publié dans cette release.

Décompresser et lancer `python3 lancer_serveur.py`. Dans Godot, appeler le serveur à `127.0.0.1:8765`. Voir le README pour le raccordement et les limites.
