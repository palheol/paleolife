extends Resource
class_name SiteData

## Fiche d'un gisement reel. Pas de "site type" pour la V1 : chaque gisement
## ne fournit que les quelques fossiles listes dans fossil_ids (voir GDD §5, §8).

@export var id: String = ""
@export var site_name: String = ""
@export var region: String = ""
@export var formation: String = "" # formation geologique / unite stratigraphique
@export var era_label: String = ""
@export var age_ma: float = 0.0
@export_multiline var description: String = ""
@export var fossil_ids: PackedStringArray = PackedStringArray()
