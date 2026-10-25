# Président — Le Destin d'une Nation

Prototype jouable HTML/Three.js pour navigateur mobile et ordinateur.

## Lancer le jeu
Le fichier principal est `index.html`. Il charge Three.js depuis jsDelivr et quelques modèles GLB CC0 depuis la banque d'assets de ce dépôt (`packs/city-kit-suburban`). Il faut une connexion internet et un navigateur moderne prenant en charge WebGL et les modules JavaScript.

Pour tester rapidement, ouvrir le fichier depuis un hébergement HTTP statique. L'ouverture directe en `file://` peut bloquer les modules ES et les modèles distants.

## Contenu du prototype
- Capitale 3D avec palais présidentiel, routes, quartiers, arbres, véhicules et unités militaires animés.
- Modèles de bâtiments Kenney GLB chargés depuis la banque d'assets.
- Navigation mobile simplifiée par icônes et sous-menus.
- Budget, dette, PIB, approbation, santé, éducation, sécurité, énergie, armée et diplomatie.
- Décisions avec coûts/conséquences, chantiers sur plusieurs jours, événements et progression.
- Sauvegarde locale automatique via localStorage.

## Limites actuelles
Ceci est une première tranche jouable, pas encore le simulateur complet. Les systèmes économiques et politiques sont des règles de prototype, le monde 3D est une capitale de démonstration et les opérations militaires sont abstraites. Les modèles distants peuvent ne pas s'afficher si le réseau ou le navigateur bloque leur chargement. Les fonctionnalités futures peuvent inclure une vraie carte nationale, des régions, des unités sélectionnables, une économie plus détaillée, des événements à choix multiples, des sons, et une progression plus profonde.

## Assets
Les modèles de ville sont issus du pack Kenney City Kit Suburban, licence CC0-1.0. Les fichiers de provenance et licence se trouvent dans `packs/city-kit-suburban`.
