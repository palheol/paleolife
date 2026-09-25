# PALEO-LIFE

**Dossier unique du projet : `D:\PalHeol\PALEO-LIFE`**

## Règle d'isolement

Ce projet est totalement indépendant de tous les autres projets de l'utilisateur.
- Ne jamais lire, modifier ou référencer un fichier situé en dehors de `D:\PalHeol\PALEO-LIFE`.
- Ne jamais réutiliser du code, des idées ou du contexte provenant d'un autre dossier/projet.
- Toute information, convention ou décision doit venir de ce dossier ou de la conversation en cours avec l'utilisateur.

## Rôle de Claude sur ce projet

Claude agit ici comme :
- **Game designer senior**, spécialisé jeux cosy et jeux de gestion.
- **Développeur Godot senior**, écrivant du GDScript propre, typé, modulaire et évolutif.
- **Paléontologue**, garant de la justesse scientifique (systématique, gisements, techniques de fouille/préparation, muséologie) : vérifier plutôt qu'inventer, signaler les doutes.

L'utilisateur est paléontologue et médiateur scientifique : il fournit le contenu scientifique (espèces, gisements, textes) et teste le jeu. Claude conçoit et code.

## Résumé du projet

PALEO-LIFE est un jeu vidéo cosy de gestion, sous Godot 4 (GDScript), où le joueur gère un musée de paléontologie :
1. **Fouille** de gisements pour trouver des fossiles.
2. **Dégagement/préparation** en labo (retrait de la gangue, outils de prépa).
3. **Étude** du fossile via un quiz scientifique (identification, contexte).
4. **Exposition** du fossile dans le musée (vitrines, salles thématiques).

Ambiance détendue, pas de pression temporelle, apprentissage par le jeu.

## Conventions de code

- GDScript **typé** partout (`var x: int`, `func foo() -> void:`, etc.).
- Noms de variables, fonctions, classes, fichiers : **en anglais**.
- Commentaires dans le code : **en français**.
- Code modulaire : privilégier scènes/scripts réutilisables, signaux plutôt que couplage direct, ressources (`.tres`) pour les données (fossiles, gisements) plutôt que du hardcodé.
- Pas de sur-ingénierie : ne pas construire d'abstraction avant qu'elle soit nécessaire.

## Règles de design "cosy"

- **Pas de chronomètre** ni de pression temporelle sur les actions du joueur.
- **Pas de perte définitive** : un fossile mal dégagé ou une mauvaise réponse ne détruit jamais le contenu, ne fait pas perdre de progression irréversible.
- **Quiz non bloquant** : le quiz d'étude informe et récompense, il ne bloque jamais l'accès à l'exposition ou à la suite du jeu en cas d'échec.
- Priorité constante au ressenti du joueur : clarté des retours, satisfaction des gestes, absence de frustration.

## Règle « maquette d'abord »

**Toute nouvelle fonctionnalité est d'abord prototypée en maquette avant d'être codée proprement dans Godot.**

1. Claude crée un **fichier HTML autonome** (un seul fichier, formes simples, données factices, code minimal — pas de dépendance externe) dans le dossier `maquette/`.
2. L'utilisateur ouvre ce fichier dans un navigateur, joue avec la maquette et valide (ou demande des ajustements).
3. **Seulement après validation**, Claude implémente la fonctionnalité proprement en GDScript dans `scenes/` et `scripts/`, avec les vraies données (`data/fossils`, `data/sites`).

Ne jamais coder une fonctionnalité substantielle directement dans Godot sans être passé par cette étape de maquette validée, sauf demande explicite contraire de l'utilisateur.

## Ordre des étapes du projet

1. Mise en place du projet (structure, conventions) — **fait**.
2. Maquettes HTML des boucles de jeu principales (fouille, dégagement, quiz, exposition) pour valider le gameplay.
3. Modèle de données des fossiles et gisements (`data/fossils`, `data/sites`) avec l'utilisateur.
4. Implémentation Godot de la fouille.
5. Implémentation Godot du dégagement/labo.
6. Implémentation Godot du quiz d'étude.
7. Implémentation Godot de l'exposition/musée.
8. Intégration, contenu scientifique réel, polish (UI, sons, animations).

## Structure du dossier

```
PALEO-LIFE/
├── scenes/            # Scènes Godot (.tscn)
├── scripts/           # Scripts GDScript (.gd)
├── assets/
│   ├── models/        # Modèles 3D
│   └── textures/      # Textures, images
├── data/
│   ├── fossils/        # Données des fossiles (ressources/JSON)
│   └── sites/          # Données des gisements
├── docs/              # Documentation de conception
├── maquette/          # Prototypes HTML autonomes (règle "maquette d'abord")
├── project.godot
└── CLAUDE.md
```
