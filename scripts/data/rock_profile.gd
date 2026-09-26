extends Resource
class_name RockProfile

## Profil de roche d'un gisement : tous les parametres visuels et de relief
## de la gangue a degager. Separe de SiteData, qui reste la fiche scientifique
## du gisement (nom, region, age...), pour ne pas melanger donnees et rendu.

@export var site_id: String = "" # doit correspondre a l'id d'une ressource SiteData
@export var display_name: String = ""

@export_group("Couleurs")
@export var base_color: Color = Color(0.86, 0.82, 0.70)
@export var accent_color: Color = Color(0.72, 0.66, 0.53)
## Teinte de la roche fraichement cassee, en profondeur (moins patinee que la surface).
@export var deep_color: Color = Color(0.62, 0.57, 0.46)

@export_group("Grain et variations")
## Frequence du grain fin (plus haut = grain plus serre).
@export var grain_scale: float = 340.0
@export_range(0.0, 1.0) var grain_strength: float = 0.08
## Frequence des grandes variations de couleur (taches, veines).
@export var mottle_scale: float = 12.0
@export_range(0.0, 1.0) var mottle_strength: float = 0.25
## Finesse du litage : eleve pour un schiste papyrace, bas pour un calcaire massif.
@export var lamination_scale: float = 900.0
@export_range(0.0, 1.0) var lamination_strength: float = 0.10
@export_range(0.0, 1.0) var roughness: float = 0.82
## Opacite du voile de poussiere, la derniere couche que le pinceau enleve :
## on doit deviner le fossile au travers, comme sous une surface sablee.
@export_range(0.0, 1.0) var dust_opacity: float = 0.55

@export_group("Relief")
## Nombre de couches a retirer avant d'atteindre le fossile.
@export var layer_count: int = 5
## Epaisseur d'une couche, en metres.
@export var layer_height: float = 0.004
## Epaisseur de la derniere couche — le voile de poussiere — en fraction d'une
## couche normale. Elle doit rester tres mince : sinon on a l'impression de
## retirer une enieme dalle de roche, au lieu de balayer une pellicule.
@export_range(0.05, 1.0, 0.01) var dust_thickness_ratio: float = 0.16
