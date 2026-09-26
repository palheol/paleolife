extends Resource
class_name FossilData

## Fiche d'un fossile (taxon). Une ressource par espece (ou par identification
## au genre seul quand l'espece n'est pas determinee : laisser "species" vide).

@export var id: String = ""

@export_group("Taxonomie")
@export var genus: String = ""
@export var species: String = "" # vide si identification au genre seulement ("sp.")
@export var author_year: String = "" # attribution scientifique, ex. "von Meyer, 1861"
@export var taxon_class: String = "" # ex. "Aves" (evite le mot-cle class_name de Godot)
@export var taxon_order: String = ""
@export var family: String = ""

@export_group("Contexte")
@export var site_id: String = "" # correspond a l'id d'une ressource SiteData
@export var age_label: String = "" # ex. "Jurassique superieur (environ 150 Ma)"
@export var age_ma: float = 0.0

@export_group("Description")
@export var size_label: String = "" # ex. "envergure d'environ 70 cm" (la dimension mesuree varie selon l'animal)
@export var size_cm: float = 0.0 # taille de l'ANIMAL vivant
## Taille reelle de la PIECE sur l'etabli, en centimetres : une plaque de
## Solnhofen et un crane isole n'ont rien de comparable. 0 = valeur par defaut
## de la scene.
@export var specimen_size_cm: float = 0.0
@export_multiline var description: String = ""
# Statut du specimen expose ; affichage sur le cartel laisse au choix du joueur (voir GDD §3.4).
@export_enum("original", "moulage", "réplique") var specimen_status: String = "original"

## Piece conservee sur plaque (lagerstatte lamine) ou degagee en volume.
## Une plaque est redressee a l'horizontale a l'arrivee sur l'etabli ; une piece
## en volume garde l'orientation de son modele, car chercher un "plan moyen" sur
## un os n'a aucun sens et le poserait dans une position arbitraire.
@export var on_plate: bool = true

@export_group("Ressources visuelles")
@export var model_path: String = "" # chemin vers le futur modele 3D (vide pour l'instant)
@export var icon_placeholder: String = "" # emoji utilise dans les maquettes en attendant
