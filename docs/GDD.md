# PALEO-LIFE — Game Design Document (V1)

> Document de conception pour la V1 (démo Steam). Basé sur le pitch fourni le 2026-09-25, complété par les arbitrages du 2026-09-25.
> Statut : brouillon de travail — la section 8 liste les points encore ouverts.

## 1. Pitch

**PALEO-LIFE** (titre provisoire) est un jeu cosy où l'on fait vivre un musée de paléontologie en suivant chaque fossile du terrain jusqu'à la vitrine.

> « Fouillez les grands gisements du monde, dégagez vos fossiles grain par grain et construisez le musée de vos rêves. »

Ton : chaleureux, lumineux, précis. Salles de musée boisées, lumière de fin d'après-midi, labo encombré et accueillant. Public visé : joueurs cosy/gestion légère (Two Point Museum, Planet Zoo version douce, PowerWash Simulator), passionnés de paléontologie, familles, enseignants.

## 2. Boucle de jeu

```
   ┌─────────┐     ┌────────┐     ┌────────┐     ┌────────────┐
   │ FOUILLE │ ──▶ │  LABO  │ ──▶ │ ÉTUDE  │ ──▶ │ EXPOSITION │
   └─────────┘     └────────┘     └────────┘     └────────────┘
        ▲                                               │
        │                                               ▼
        └──────────────────  ÉCONOMIE  ◀────── visiteurs, revenus
                 (achats d'outils, modèles de diorama,
                  agrandissement) réinjectés dans la Fouille
```

1. **Fouille** — le joueur entre dans une zone de fouille et en extrait des fossiles pris dans leur gangue.
2. **Labo** — il dégage le fossile et recolle ce qui se fissure.
3. **Étude** — un quiz scientifique débloque une page d'encyclopédie et fixe la richesse du cartel exposé (et rapporte de l'argent).
4. **Exposition** — le fossile préparé rejoint une vitrine ou un diorama, dans une galerie composée par le joueur.
5. **Économie** — les visiteurs rapportent de l'argent, réinvesti dans l'activité en amont (outils, modèles de diorama, agrandissement).

La boucle est conçue pour ne jamais forcer le joueur : chaque étape peut être quittée et reprise sans pénalité, et chaque fossile progresse à son rythme.

## 3. Activités détaillées

### 3.1 Fouille

- **V1 : pas de gisement nommé.** Le joueur choisit une zone de fouille et **tombe directement dedans** — pas de carte de prospection ni d'indices de surface à ce stade.
- Référence de gameplay : la mécanique s'inspire du **Souterrain de Pokémon Diamant/Perle** — une grille que l'on dégage progressivement, révélant des fossiles pris dans la roche, sans notion de chrono ni d'échec.
- Il **creuse** dans la zone et **rapporte des fossiles** encore pris dans leur gangue vers le labo.
- Pas de chrono, pas d'échec possible.
- La gangue est **générée par le code** : une plaque creusée couche par couche en 2,5D — format cohérent avec les fossiles « en plaque » utilisés pour le prototypage (voir §5).

### 3.2 Labo

Cœur tactile et relaxant du jeu.

- **Outils V1** : micro-percuteur (dégagement de la gangue), pinceau (nettoyage fin, dépoussiérage), colle (recollage des fissures — **la colle fait aussi office de consolidant**, pas d'outil séparé en V1).
- Le dégagement se fait **couche par couche** sur la plaque 2,5D ramenée de la fouille.
- **Jauge de risque en temps réel** : le risque de fissure dépend de l'**amplitude du geste** et de la **vitesse de dégagement** — plus les deux sont élevés (grand trait rapide au percuteur), plus le risque grimpe. Un geste lent et précis est le plus sûr. La jauge doit être visible en direct pendant le dégagement, pour que le joueur ajuste son geste sans surprise.
- **Recollage** : si le fossile se fissure, il se recolle toujours avec la colle ; **pas de perte définitive**, seulement une **légère baisse de valeur scientifique** du spécimen.
- Feedback sensoriel soigné : son du micro-percuteur, poussière qui s'envole, grain qui se révèle progressivement — c'est l'activité qui doit convaincre en premier (point de décision de l'étape 2 de la feuille de route).

### 3.3 Étude

- Un **quiz court** porte sur l'anatomie du fossile, sa famille, son âge géologique et son gisement d'origine.
- Le quiz **débloque une page d'encyclopédie**, illustrée par le rendu du fossile tel que préparé par le joueur.
- Le résultat du quiz **fixe le contenu du cartel** exposé, par paliers d'information :
  - **Minimum garanti** : nom de genre et d'espèce, localisation, âge.
  - **Paliers supplémentaires** (selon le score) : famille, longueur du spécimen adulte, texte descriptif, image, etc.
- **Plus les réponses sont correctes, plus le joueur gagne d'argent** pour son musée (récompense économique directe du quiz, en plus du cartel enrichi).
- **Non bloquant** : une mauvaise réponse donne un **indice** et permet de **réessayer**, sans limite de tentatives ni pénalité de temps.

### 3.4 Exposition

- **V1 : une grande salle rectangulaire d'environ 1000 m² virtuels**, que le joueur aménage librement : vitrines, enclos, murs, et **bancs pour les visiteurs** s'il le souhaite. Les modèles 3D d'aménagement seront fournis progressivement.
- **Diorama** : au départ, aucun animal/modèle n'y figure. Le joueur doit **commander** des modèles (reconstitutions/statues) pour le peupler. **Plus le modèle commandé est lié thématiquement aux fossiles déjà exposés** (même espèce, même écosystème, même période), **plus le bonus économique est élevé**.
- Le joueur **compose ses propres galeries** ; une présentation cohérente et variée (fossiles + squelettes + statues, bien organisés) est valorisée économiquement (voir §3.5).
- **Salle d'expositions temporaires** (V1 : jusqu'à 200 m² max) : thèmes ponctuels montés avec les fossiles disponibles, des moulages et des modèles du catalogue. Attire un pic de visiteurs puis se renouvelle. *Thème de la V1 encore à définir (voir §8).*

### 3.5 Économie

**Revenus**
- Entrées des visiteurs (seule source en V1). **Pas de prix de billet fixe imposé** : la fréquentation (et donc les revenus) augmente qualitativement avec :
  - la **quantité** de fossiles/pièces exposées ;
  - la **qualité de l'organisation** des galeries (cohérence, rangement) ;
  - la **diversité** des types d'objets présentés (fossiles, squelettes *et* statues dans les dioramas) ;
  - la qualité des réponses au quiz (voir §3.3).
  - *La formule chiffrée exacte reste à concevoir au moment de l'implémentation (voir §8).*
- *Hors V1* : moulages échangés avec d'autres musées, événements (visites scolaires, prêts, chercheurs en résidence).

**Dépenses**
- Achat d'outils de labo.
- Commande de modèles pour le diorama (V1, voir §3.4).
- Embauche de techniciens *(hors V1)*.
- Ouverture de nouveaux sites de fouille *(hors V1)*.
- Catalogue élargi de statues grandeur nature *(hors V1 — la V1 se limite aux modèles de diorama basiques)*.
- **Agrandissement du musée** : déclenché par une combinaison **argent disponible + espace au sol restant** (surface libre non occupée par vitrine/fossile). Sous un seuil calculé, il faut envisager une nouvelle salle, qui se remplit ensuite progressivement (V1 : une réserve + une salle supplémentaire à débloquer). *Seuil exact à calibrer lors du prototypage (voir §8).*

## 4. Règles cosy — application concrète

Ces règles ne doivent jamais être trahies, quelle que soit l'activité :

| Règle | Application |
|---|---|
| **Pas de chrono** | Aucune activité principale (fouille, labo, quiz) n'a de minuteur ni de pénalité liée à la vitesse. |
| **Pas de perte définitive** | Un fossile fissuré au labo se recolle toujours ; malus de valeur scientifique, jamais de perte du spécimen ou de la progression. |
| **Visiteurs simples** | Les visiteurs se promènent, regardent, commentent (avec humour, y compris des idées reçues à corriger via panneaux) ; aucun besoin à gérer (faim, satisfaction individuelle, etc.). |
| **Quiz non bloquant** | Une erreur donne un indice et permet de réessayer ; le joueur n'est jamais empêché d'avancer par le quiz. |

## 5. Contenu exact de la V1

| Élément | Contenu V1 |
|---|---|
| Gisements | Aucun site nommé — le joueur entre directement dans une zone de fouille générique (voir §3.1) |
| Fossiles | 8 visés pour la V1 ; 5 modèles d'entraînement disponibles pour l'instant (voir ci-dessous) |
| Outils du labo | Micro-percuteur, pinceau, colle (colle = recollage + consolidant) |
| Musée | 1 grande salle ~1000 m², aménagement libre (vitrines, enclos, murs, bancs) + 1 diorama à peupler |
| Expositions temporaires | 1 salle, jusqu'à 200 m² max, thème à définir |
| Place / agrandissement | Seuil calculé sur l'espace au sol restant + argent disponible ; au-delà, nouvelle salle à envisager |
| Économie | Entrées des visiteurs uniquement, formule qualitative (quantité + organisation + diversité) |
| Langues | Français, anglais |

### Modèles de prototypage (5 fossiles placeholder)

Pour tester le pipeline fouille → labo → étude sans dépendre d'un gisement précis, 5 modèles sont utilisés en interne :

| Espèce | Groupe | Contexte scientifique réel |
|---|---|---|
| *Confuciusornis sanctus* | Oiseau primitif | Crétacé inférieur (~125 Ma), biota de Jehol, Liaoning (Chine) |
| *Archaeopteryx lithographica* | Dinosaure à plumes / proto-oiseau | Jurassique supérieur (~150 Ma), calcaires de Solnhofen (Allemagne) |
| *Propalaeotherium* sp. | Mammifère (cheval primitif) | Éocène (~47 Ma), gisements allemands (dont Messel, Geiseltal) |
| *Scorpaena* sp. | Poisson (rascasse, Scorpaenidae) | Connu à l'état fossile dans plusieurs gisements marins (ex. Monte Bolca, Italie, Éocène) |
| *Pachyophis woodwardi* | Serpent marin primitif | Crétacé (~95 Ma), Podumci (Croatie/Bosnie) |

⚠️ **Ces 5 modèles sont sous licence non commerciale.** Ils servent **uniquement au prototypage et à l'entraînement en interne** (maquettes HTML, tests de la boucle Godot). Ils ne doivent **jamais** figurer dans un build public ou commercial. Ils proviennent aussi de gisements et d'époques différents (Chine, Allemagne, Italie, Balkans — du Jurassique au Crétacé) : ce n'est pas une faune cohérente d'un seul site, ce qui correspond bien au choix de ne pas nommer de gisement en V1. La liste définitive des 8 fossiles commerciaux reste à établir (voir §8).

## 6. Écrans et menus

- **Écran titre** — Jouer / Continuer / Options / Quitter
- **Menu principal du musée** (hub) — accès à Fouille, Labo, Exposition, Économie, Encyclopédie, Sauvegarde
- **Zone de fouille** — grille de dégagement façon « Souterrain » (pas de carte de prospection séparée en V1)
- **Établi du labo** — dégagement du fossile (micro-percuteur, pinceau, colle), vue rapprochée de la plaque, jauge de risque en temps réel
- **Inventaire des fossiles** — fossiles en gangue / en cours de préparation / prêts pour l'étude
- **Écran de quiz** — questions anatomie / famille / âge / gisement, indices, résultat
- **Page d'encyclopédie** — fiche du fossile, rendu personnalisé, cartel par paliers selon score du quiz
- **Éditeur de galerie / musée** — aménagement libre de la salle (vitrines, enclos, murs, bancs)
- **Catalogue de commande** — modèles à acheter pour peupler le diorama, avec indicateur de lien thématique
- **Salle d'exposition temporaire** — sélection du thème, des pièces exposées (fossiles + moulages/modèles)
- **Écran économie** — revenus (fréquentation liée à la collection), achats (outils, modèles), suivi de l'espace au sol restant
- **Réserve** — pièces non exposées, en attente de place
- **Paramètres** — langue (FR/EN), audio, affichage
- **Sauvegarde / chargement**

## 7. Hors V1

Tout ce qui attend que la boucle labo → exposition soit validée amusante :

- **Gisements** réels nommés et jouables : jusqu'à 6 à 8 sites au total à terme (liste à définir, en fonction des sources de fossiles/moulages/modèles disponibles sous licence appropriée).
- **Fossiles** : extension de 8 à 60–100 spécimens.
- **Outils de labo avancés** : acide, loupe, outils de dégagement améliorés.
- **Musée** : plusieurs ailes, dioramas classés par période sur plusieurs salles, catalogue élargi de statues grandeur nature, réaménagement et remplacement de salles, étages supplémentaires.
- **Économie étendue** : moulages échangés avec d'autres musées, événements (visites scolaires, prêts, chercheurs), embauche de techniciens, formule chiffrée précise de fréquentation.
- **Expositions temporaires** : thèmes variés, affiches, prêts d'autres musées, pics de fréquentation modélisés plus finement.
- **Langues** additionnelles selon le succès commercial.
- **Gangue en voxels** pour les os isolés (au-delà du format plaque 2,5D de la V1).
- **Carte de prospection avec indices de surface** : la V1 saute directement en zone de fouille ; une couche de prospection plus riche pourrait revenir plus tard.
- **Intégration Steam (GodotSteam)** : *faisabilité confirmée* — un jeu Godot se publie sur Steam sans problème (Steamworks accepte n'importe quel exécutable ; des jeux connus comme *Dome Keeper* ou *Brotato* sont faits en Godot). GodotSteam n'est nécessaire que si l'on veut utiliser des fonctionnalités Steam spécifiques (succès, cloud save, etc.) depuis le jeu. Calendrier d'intégration encore à définir (voir §8).

## 8. Questions à trancher

1. **Titre définitif** — toujours ouvert ; piste donnée : quelque chose qui évoque davantage le musée qu'un nom générique.
2. **Liste définitive des 8 fossiles « commerciaux » de la V1** — les 5 modèles actuels (Confuciusornis, Archaeopteryx, Propalaeotherium, Scorpaena, Pachyophis) sont des placeholders non commerciaux réservés au prototypage (voir §5) ; il faudra soit des licences commerciales, soit des modèles sur mesure, avant toute diffusion publique, et compléter jusqu'à 8.
3. **Thème de l'exposition temporaire de la V1** — à définir ultérieurement.
4. **Formule exacte de fréquentation/revenus des visiteurs** — le principe qualitatif est acté (§3.5), la formule chiffrée reste à concevoir lors de l'implémentation.
5. **Seuil exact de déclenchement de l'agrandissement** (espace au sol restant) — à calibrer lors du prototypage.
6. **Textes des cartels, répliques des visiteurs et idées reçues à corriger** — contenu à rédiger ensemble.
7. **Sources précises des modèles 3D définitifs** (Sketchfab, MorphoSource, Cults3D, autres) — à identifier au fur et à mesure, licence commerciale à vérifier systématiquement.
8. **Calendrier de l'intégration GodotSteam** — faisabilité confirmée (voir §7), mais timing encore à définir.
