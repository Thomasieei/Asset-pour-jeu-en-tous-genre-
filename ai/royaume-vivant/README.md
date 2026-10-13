# IA locale gratuite — Qwen3 pour Godot

**Télécharger les vrais poids et le runtime Linux :**
https://github.com/Thomasieei/Asset-pour-jeu-en-tous-genre-/releases/tag/royaume-vivant-ia-v1

Le fichier `Royaume-Vivant-IA-Locale.zip` de cette version contient le GGUF Q4_K_M réel, le serveur Linux, les licences et les tests. Les fichiers volumineux sont dans la release ; ce dossier contient les sources légères et le raccordement Godot. Aucun personnage, bâtiment ou projet de jeu n’est ajouté ici.

`build_bundle.py` reproduit le modèle fourni depuis les poids officiels téléchargés et le runtime llama.cpp figé. Il contrôle leurs SHA-256 avant publication. `SHA256SUMS.txt` dans la release permet de vérifier le pack téléchargé.

`godot/ai_provider.gd` est l’adaptateur source testé. Il attend une simulation proposant `npcs` et `buildings` pour son validateur ; adapter cette interface à votre projet. `godot/inhabitants.json` contient les dix profils de départ. Ce code n’est pas un plugin d’inférence natif Android : il contacte un serveur local séparé.

---

# Vrai modèle local pour Royaume Vivant

Ce pack contient les **poids réels Qwen3 0.6B Q4_K_M** issus d’une requantification du Q8_0 officiel téléchargé, le runtime llama.cpp **b11598 Linux x86_64 CPU**, leurs licences et les sorties des tests. Ce sont des fichiers réellement téléchargés et exécutés, pas une liste de liens.

Les poids GGUF peuvent être employés sur d’autres plateformes avec un runtime adapté. **Les exécutables de ce pack sont Linux x86_64, pas Android ni Windows.** Le poids n’est pas inclus dans l’APK, qui fonctionne à règles sans connexion. L’intégration native Android reste à réaliser.

## Lancer sur Linux x86_64

Décompresser l’archive. Depuis ce dossier :

```sh
chmod +x runtime/llama-server
python3 lancer_serveur.py
```

Le serveur charge une seule copie des poids et écoute uniquement `127.0.0.1:8765`. Laisser ce terminal ouvert. Dans Godot, lancer le projet, ouvrir Ordres et activer le mode modèle local. Les profils des dix PNJ sont envoyés successivement au même modèle, à intervalle limité. Aucun compte ni clé API n’est requis.

La machine doit disposer de suffisamment de mémoire pour le modèle, le contexte et le jeu. Le fichier de poids d’environ 378,3 MiB n’est pas une limite de RAM : prévoir une marge de plusieurs gigaoctets pour une session de développement. Le maximum RSS du lot de test Linux était d’environ 1,2 GiB, sans isolation du modèle ; il n’est pas une mesure de téléphone.

## Tests

Serveur lancé, dans un second terminal :

```sh
python3 tests/test_ordres.py
```

Dans le dossier du projet Godot :

```sh
godot --headless --path royaume-vivant --script res://tests/ai_integration.gd
```

La série de cinq ordres a été reconnue. L’appel d’ordre depuis Godot fonctionne. Avec le Q4 livré, 9 des 10 profils sains ont produit l’intention attendue ; Nessa et deux situations de besoins ont été mal interprétées. La série Q8 précédente, également fournie comme preuve, avait 10 profils sains conformes et deux erreurs de besoins. Les JSON fournis montrent ces erreurs. Les réponses ne possèdent pas le droit d’exécuter du code ni de modifier des stocks ; la simulation déterministe impose besoins, ressources, permissions et terrain.

Il ne s’agit pas de dix IA indépendantes, ni d’un modèle qui s’entraîne en continu. Chaque habitant a un profil et une mémoire séparés, utilisés comme contexte par un modèle partagé. Les échanges sociaux et dialogues informatifs du jeu restent écrits à règles ; aucun dialogue libre n’est annoncé comme intégré.

## Licences et provenance

- Qwen3 0.6B GGUF officiel : https://huggingface.co/Qwen/Qwen3-0.6B-GGUF — Apache 2.0. Licence complète dans `licenses/QWEN-LICENSE`. **Modification : requantification Q8_0 → Q4_K_M par llama-quantize b11598 avec --allow-requantize. Cette transformation avec pertes a été signalée et testée. Aucun réentraînement. Le fichier Q8 original n’est pas fourni pour respecter la limite de taille du téléchargement.**
- llama.cpp : https://github.com/ggml-org/llama.cpp/releases/tag/b11598 — MIT. Licence dans `licenses/LLAMA-LICENSE`. Runtime binaire amont.
- Lanceur et test Python de ce projet : MIT, fichier LICENSE du projet source.

Ne pas confondre la possibilité de compiler llama.cpp sur Android avec un plugin Godot Android livré. Lire `docs/IA_LOCALE.md` dans le projet pour le diagnostic et les étapes manquantes.
