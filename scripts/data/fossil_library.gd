extends RefCounted
class_name FossilLibrary

## Catalogue des fiches presentes dans data/ : fossiles, gisements et profils de
## roche, relies entre eux par leur identifiant. Evite d'avoir a declarer chaque
## piece a la main dans les scenes.

const FOSSILS_PATH := "res://data/fossils"
const SITES_PATH := "res://data/sites"
const PROFILES_PATH := "res://data/rock_profiles"

static var _fossils: Array[FossilData] = []
static var _sites: Dictionary = {}
static var _profiles: Dictionary = {}
static var _loaded: bool = false

static func all_fossils() -> Array[FossilData]:
	_ensure_loaded()
	return _fossils

## Gisement d'ou provient la piece, ou null si la fiche n'en designe aucun.
static func site_for(fossil: FossilData) -> SiteData:
	_ensure_loaded()
	if fossil == null:
		return null
	return _sites.get(fossil.site_id, null)

## Profil de roche du gisement correspondant, pour ne pas preparer un specimen
## dans une matrice qui n'est pas la sienne.
static func profile_for(fossil: FossilData) -> RockProfile:
	_ensure_loaded()
	if fossil == null:
		return null
	return _profiles.get(fossil.site_id, null)

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for resource in _load_folder(FOSSILS_PATH):
		var fossil := resource as FossilData
		if fossil != null:
			_fossils.append(fossil)
	for resource in _load_folder(SITES_PATH):
		var site := resource as SiteData
		if site != null:
			_sites[site.id] = site
	for resource in _load_folder(PROFILES_PATH):
		var profile := resource as RockProfile
		if profile != null:
			_profiles[profile.site_id] = profile
	_fossils.sort_custom(func(a: FossilData, b: FossilData) -> bool: return a.id < b.id)

static func _load_folder(path: String) -> Array:
	var found: Array = []
	for file in DirAccess.get_files_at(path):
		# Une ressource exportee se presente sous la forme "xxx.tres.remap".
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var resource := ResourceLoader.load(path.path_join(name))
		if resource != null:
			found.append(resource)
	return found
