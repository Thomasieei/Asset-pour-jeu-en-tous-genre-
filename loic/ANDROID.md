# Loïc — Aurore — interface V0.6

V0.6 met à jour Aurore V0.4/V0.5 avec le même paquet et le même certificat. Installer par-dessus Aurore pour conserver ses sauvegardes. Ne pas désinstaller l’application.

Les modèles animés sont calibrés après leur première pose pour poser les pieds sur le sol. Le saut et l’accroupissement agissent sur un parent distinct des animations importées. Les bâtiments en pente ont des fondations. Les morceaux de terrain, leurs collisions, les objets et les personnages partagent la même fonction de hauteur, y compris au-delà du village. Les collines décoratives ont été remplacées par un relief parcourable.

Le monde garde une étendue de 2 km sur 2 km. Le terrain visible est chargé en 49 zones au maximum, et la caméra tourne avec un glissement sur le décor. La population passe à 192 créatures persistantes, dont plusieurs près des sorties, avec au maximum 12 actives. Les individus déjà sauvegardés gardent leur identité et leurs souvenirs.

Les actions à droite sont disposées en deux petites colonnes de cases carrées noires, bordées de blanc et espacées. Leur côté varie de 48 à 64 unités selon la hauteur de l’écran ; la grille reste en bas à droite. Elles permettent de frapper, sauter, s’accroupir et discuter. La case marquée d’une étoile déclenche une onde de choc : rayon 5 mètres, 32 dégâts, recharge de 6 secondes. La frappe inflige 18 dégâts avec une recharge de 0,7 seconde. Les frappes ont un effet visible et les ennemis affichent leurs PV.

Pour réduire l’attente, les conversations utilisent au maximum 48 tokens de sortie, un contexte plus court et interrompent un calcul ambiant moins prioritaire. Sur téléphone, la simulation autonome continue avec ses règles tandis que le modèle local est réservé aux conversations. Une requête de dialogue est interrompue après 30 secondes et son secours est explicitement étiqueté. La bibliothèque native et les poids Qwen sont ceux de V0.4 : aucun serveur, compte ou accès Internet n’est nécessaire. La vitesse réelle dépend du téléphone et n’a pas été mesurée sur Android ici.

## Vérification

20 contrôles ciblés exécutés avec Godot 4.3 en mode headless Linux : position effective des pieds après animation, poses de saut et d’accroupissement, dégâts et recharges de frappe et d’onde, création d’effets, population, budget d’ennemis et concordance du sol physique avec le sol visuel, y compris hors du village. Le rapport est `tests/validation_correctifs.json`.

L’APK corrigée a été reconditionnée depuis la V0.4 vérifiée avec `build/patch_android.py`, en remplaçant les scripts exportés par les sources GDScript et en actualisant leur registre. Les assets importés et les bibliothèques natives sont conservés, les poids ont été vérifiés, puis l’APK a été alignée et signée avec le certificat Aurore. Le paquet porte versionCode 5 et versionName 0.5-aurore. Les sources empaquetées correspondent aux sources testées.

Cette APK n’a pas été exécutée sur un appareil Android pendant ces vérifications. Le rendu, la rotation tactile, la fluidité du téléphone et le temps de réponse de Qwen restent donc à confirmer sur l’appareil. Les anciens rapports de tests de V0.4 sont conservés ; ils ne constituent pas une nouvelle validation de V0.5.

Le modèle simule des personnalités et utilise les outils prévus par le jeu ; il ne réécrit pas son code. Le jeu reste un prototype local, sans multijoueur. La seconde faction reste à concevoir après stabilisation.
