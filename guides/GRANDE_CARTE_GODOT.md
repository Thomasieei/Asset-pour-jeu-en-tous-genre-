# Grande carte RPG pour Thomas — brief à utiliser par Claude

## Objectif demandé

Créer une grande carte 3D stylisée, belle et lisible sur mobile : camps, falaises, grotte, eau, arbres et détails variés. Les belles routes et les paysages ouverts sont prioritaires. Éviter une forêt dense uniforme, le remplissage aléatoire et la répétition visible. Ce document est une proposition de conception ; aucune scène de carte n’est encore livrée avec ce guide.

## Direction artistique

Utiliser une palette cohérente : herbe vert doux, terre chaude, roches grises légèrement bleutées, bois brun et eau turquoise. Choisir une lumière principale douce et des ombres lisibles. Les silhouettes doivent rester claires depuis la vraie caméra du jeu. Établir une échelle commune avec le personnage avant d’assembler les packs ; un bâtiment conçu pour un plateau hexagonal peut être trop petit pour y entrer.

Favoriser KayKit Forest pour la végétation et KayKit Dungeon pour les intérieurs. Les bâtiments Medieval Hexagon sont des candidats à examiner, pas automatiquement des maisons habitables. Nature Kit, Castle Kit et Survival Kit apportent ponts, rochers et accessoires : comparer matériaux, proportions et couleurs avant de les mélanger. Ne pas poser une immense grille d’hexagones visibles comme sol final.

## Taille et parcours proposés

Cible de travail : environ 800 × 800 mètres, à adapter à la vitesse du joueur, à la caméra et au téléphone. Construire d’abord un quartier finalisé de 200 × 200 mètres qui contient route, camp, rive et relief. Étendre ensuite la carte en conservant ce niveau de détail. Une grande surface vide n’est pas une carte aboutie.

Le parcours principal forme une boucle : hameau → prairie → lac → falaises → ruines → retour au hameau. Deux raccourcis relient des branches et évitent les longs retours. L’entrée de grotte est visible depuis une corniche ou un virage ; un chemin permet réellement de l’atteindre. Placer quelques repères reconnaissables de loin : tour ruinée, grand rocher, pont et arbre remarquable.

## Zones à composer à la main

| Zone | Terrain et silhouette | Détails distinctifs | Circulation |
|---|---|---|---|
| Hameau d’entrée | Colline basse, petite place | Quelques maisons, charrette, puits, clôtures interrompues | Route claire, sortie visible |
| Prairie | Grands espaces ouverts, relief doux | Rochers isolés, fleurs par petites touches, ancien muret | Route sinueuse, chemin secondaire |
| Lac et ruisseau | Rive irrégulière, une berge haute | Pont, ponton, roseaux en petits groupes, camp de pêche | Chemin longeant une partie de l’eau |
| Camp de bandits | Replat protégé par des rochers | Tentes, feu, caisses, surveillance, butin | Entrée et issue secondaire, aire de combat libre |
| Ancienne carrière | Falaises étagées, sol minéral | Chariot, outils, piles de pierre, treuil si disponible | Route plus étroite, lacets praticables |
| Grotte | Entrée sombre et encadrée par la roche | Rochers, lumière ponctuelle, intérieur avec salles | Traversée réelle ; entrée sans blocage |
| Ruines | Plateau, silhouette de tour cassée | Arches, piliers, escaliers courts, herbe localisée | Clairière de combat et raccourci |
| Bosquet | Petites poches boisées séparées | Souches, tronc tombé, passage secret | Chemins et clairières dégagés |

Chaque camp doit raconter une activité : pêche, exploitation de pierre ou banditisme. Changer disposition, accessoires, relief et éclairage ; ne pas dupliquer trois fois le même camp avec une autre couleur.

## Routes : élément central du décor

Routes principales d’environ 5–7 m, chemins secondaires 2–3 m : valeurs initiales à régler selon la caméra. Courbes douces, virages avec une destination perceptible, élargissements près des camps et jonctions naturelles. Faire suivre au chemin le relief et les lieux utiles.

Créer des bordures irrégulières entre terre et herbe, quelques pierres ou traces de passage, et des raccords propres aux ponts. Alterner terre, zones pierreuses et quelques passages pavés selon la zone. Éviter la bande rectangulaire plate posée sur le terrain, les angles à 90° systématiques, les détails décoratifs qui bloquent le passage et les décalcomanies superposées qui scintillent.

## Arbres et densité

Comme point de départ, réserver environ 15–25 % de la surface à des poches boisées et conserver une majorité d’espaces ouverts. C’est une intention de composition, pas un objectif de comptage exact. Grouper les arbres sur certaines crêtes, près d’une rive et derrière les camps ; laisser respirer les prairies. Près des lieux de combat, utiliser quelques arbres qui encadrent la vue plutôt qu’un couvert complet.

Vérifier la caméra réelle : pas de feuillage qui masque le joueur, l’ennemi, la sortie de grotte ou la route. Prévoir l’effacement visuel des obstacles de premier plan si nécessaire. Ajouter herbe et fleurs en touches, pas sur chaque mètre carré. Les objets de récolte doivent être identifiables et accessibles.

## Falaises, eau et grotte

Faire des reliefs continus : pieds de falaises raccordés au terrain, corniches utilisables, chemins praticables et silhouettes variées. Les limites de carte doivent s’intégrer au paysage. Examiner les assets disponibles ; si aucun module de falaise ou d’entrée ne convient, fabriquer une géométrie propre et cohérente plutôt qu’étirer un petit rocher jusqu’à dégrader son apparence.

L’eau doit suivre les berges sans trous, avec une couleur stable et un effet de surface discret adapté au moteur de rendu choisi. Décider explicitement si la rivière est traversable : pont, gué ou collision lisible. Éviter les effets de réflexion coûteux non testés sur le téléphone cible.

La grotte doit être explorable. L’intérieur peut être une scène distincte reliée par une transition discrète, ou une portion chargée à proximité. Prévoir plusieurs salles, variations de largeur, quelques accessoires et un objectif. Une simple ouverture noire décorative ne répond pas à la demande.

## Méthode de construction

1. Lire AGENTS.md, catalog.json et le manifeste d’exemples adjacent. Utiliser les chemins réels et conserver licences et dépendances.
2. Construire le relief, le réseau de routes et les limites. Tester le parcours avec personnage et caméra avant de décorer.
3. Composer le quartier de 200 × 200 m avec qualité finale. Présenter des captures en jeu, pas seulement une vue d’éditeur.
4. Étendre les zones à la main autour des routes et points d’intérêt. Utiliser le placement procédural seulement dans des zones autorisées, avec exclusions autour des chemins, bâtiments, combats et entrées. Garder une graine reproductible et la possibilité de corriger les placements.
5. Ajouter la navigation et des collisions simplifiées cohérentes avec les surfaces praticables. Préserver une aire libre autour des ennemis, coffres et interactions.
6. Prévoir un chargement par portions, une réduction de détails à distance et le regroupement des petits décors répétés. Mesurer mémoire, temps d’image et chargements sur le téléphone cible ; les imports validés de la banque ne garantissent pas les performances d’une grande scène.
7. Tester l’ensemble du trajet et produire une scène réelle, un manifeste des assets retenus, des captures et un bilan des limites restantes.

## Critères de livraison

- Les huit zones ont des silhouettes et des accessoires distincts ; les transitions entre elles sont naturelles.
- La carte contient des routes travaillées, des espaces ouverts, une eau bien raccordée et une grotte réellement accessible.
- Aucun arbre, rocher ou décor ne masque durablement une interaction ou ne rend un passage impossible.
- Le joueur peut parcourir la boucle et les raccourcis sans blocage ; navigation et collisions sont testées.
- Pas de textures manquantes, d’assets pixel art ajoutés, de végétation distribuée partout ni de props gris de prototypage présentés comme résultat final.
- La carte est jugée depuis la caméra mobile : profondeur, couleurs, repères et combats restent lisibles.
- Une APK n’est annoncée comme jouable qu’après vérification du lancement, des contrôles, du parcours et des performances sur l’appareil cible.

## Instruction courte à donner à Claude

« Lis guides/GRANDE_CARTE_GODOT.md et guides/MAP_ASSET_EXAMPLES.json dans la banque d’assets. Construis une grande carte RPG stylisée avec routes travaillées, camps différents, falaises, lac/ruisseau, grotte explorable, ruines et petits bosquets. Priorité aux paysages ouverts et à la diversité, pas à une forêt dense partout. Commence par un quartier finalisé de 200 × 200 m et étends ensuite vers environ 800 × 800 m après validation du style et des performances. Livre de vraies scènes Godot, des captures depuis la caméra du jeu et les résultats des tests de circulation. »
