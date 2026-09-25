extends Node3D
class_name LabScene

## Scene du labo : un specimen scanne (GLB) recouvert d'une gangue generee par
## code, vue de dessus avec une camera orbitale douce.
##
## Le scan de musee contient deja sa propre plaque de roche : on ne l'enterre donc
## pas dans un bloc, on empile la gangue PAR-DESSUS lui. C'est le geste reel de
## preparation (retirer le recouvrement), et ca colle au GDD §3.2.

const SHADER_PATH := "res://assets/shaders/rock_slab.gdshader"

@export var fossil: FossilData
@export var rock_profile: RockProfile

@export_group("Plaque")
## Plus grande dimension horizontale visee pour le specimen, en metres.
@export var specimen_size_m: float = 0.45
@export var cell_size: float = 0.01
## Marge de gangue autour du specimen, en metres.
@export var margin_m: float = 0.015
## De combien le point le plus haut du fossile depasse une fois la gangue retiree.
@export var protrusion_m: float = 0.0015

@export_group("Indice de depart")
## Petite zone deja erodee qui laisse deviner ou commencer (comme un fossile
## qui affleure naturellement sur le terrain).
@export var hint_radius_cells: int = 3
@export var hint_remaining_layers: int = 0
## Fraction centrale de la plaque ou chercher le point d'affleurement (0.6 = 60 %).
@export_range(0.1, 1.0, 0.05) var hint_search_area: float = 0.55

@export_group("Import du scan")
## Fragments de noms de noeuds a ignorer dans le GLB (objets parasites Sketchfab).
@export var excluded_node_names: PackedStringArray = PackedStringArray(["Cube"])

@onready var _slab: RockSlab = $RockSlab
@onready var _fossil_root: Node3D = $FossilRoot
@onready var _camera: OrbitCamera = $OrbitCamera
@onready var _key_light: DirectionalLight3D = $KeyLight
@onready var _fill_light: DirectionalLight3D = $FillLight

var _status_label: Label

func _ready() -> void:
	_build_lighting()
	_build_status_label()

	if rock_profile == null:
		_warn("Aucun profil de roche assigne sur la scene Lab.")
		return

	# Garde-fou scientifique : le profil de roche doit correspondre au gisement
	# d'ou vient le fossile, sinon on prepare un specimen dans la mauvaise roche.
	if fossil != null and fossil.site_id != rock_profile.site_id:
		_warn("%s vient du gisement '%s' mais la roche chargee est '%s'."
			% [fossil.id, fossil.site_id, rock_profile.site_id])

	var meshes := _setup_specimen()
	if meshes.is_empty():
		return

	_build_slab(_specimen_footprint(meshes))
	_carve_starting_hint(meshes)

	_camera.focus_on(
		Vector3(0.0, _slab.position.y + _slab.surface_y() * 0.5, 0.0),
		maxf(_slab.size_x(), _slab.size_z()))

	var title := rock_profile.display_name
	if fossil != null:
		title = "%s %s — %s" % [fossil.genus, fossil.species, rock_profile.display_name]
	_set_status("%s · plaque %d × %d cm"
		% [title, roundi(_slab.size_x() * 100.0), roundi(_slab.size_z() * 100.0)])

# --- Specimen ---------------------------------------------------------------

## Charge le GLB, le remet a l'echelle et le place : centre en XZ, sommet a y = 0.
## Retourne les maillages retenus (hors objets parasites).
func _setup_specimen() -> Array[MeshInstance3D]:
	var empty: Array[MeshInstance3D] = []
	if fossil == null or fossil.model_path.is_empty():
		_warn("Aucun modele 3D renseigne sur la fiche fossile.")
		return empty
	if not ResourceLoader.exists(fossil.model_path):
		_warn("Modele introuvable : %s\n(laisse Godot importer le .glb, ca peut prendre un moment)"
			% fossil.model_path)
		return empty

	var packed := load(fossil.model_path) as PackedScene
	if packed == null:
		_warn("Le fichier %s n'a pas pu etre charge comme scene." % fossil.model_path)
		return empty

	var model := packed.instantiate() as Node3D
	_fossil_root.add_child(model)

	var meshes := _collect_meshes(model)
	if meshes.is_empty():
		_warn("Aucun maillage exploitable dans %s." % fossil.model_path)
		return empty

	var bounds := _combined_aabb(model, meshes)
	var largest := maxf(bounds.size.x, bounds.size.z)
	if largest <= 0.0:
		_warn("Le modele a une emprise horizontale nulle.")
		return empty

	var scale_factor := specimen_size_m / largest
	model.scale = Vector3.ONE * scale_factor

	var scaled := AABB(bounds.position * scale_factor, bounds.size * scale_factor)
	model.position = Vector3(-scaled.get_center().x, -scaled.end.y, -scaled.get_center().z)
	return meshes

## Tous les MeshInstance3D du modele, sauf ceux dont le nom (ou celui d'un parent)
## contient un fragment exclu. Les exclus sont masques plutot que supprimes.
func _collect_meshes(root: Node3D) -> Array[MeshInstance3D]:
	var kept: Array[MeshInstance3D] = []
	for node in _descendants(root):
		var instance := node as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		if _is_excluded(instance, root):
			instance.visible = false
			continue
		kept.append(instance)
	return kept

func _is_excluded(node: Node, root: Node) -> bool:
	var current := node
	while current != null:
		var node_name := String(current.name)
		for fragment in excluded_node_names:
			if not fragment.is_empty() and node_name.contains(fragment):
				return true
		if current == root:
			break
		current = current.get_parent()
	return false

func _descendants(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in root.get_children():
		found.append(child)
		found.append_array(_descendants(child))
	return found

func _combined_aabb(root: Node3D, meshes: Array[MeshInstance3D]) -> AABB:
	var result := AABB()
	var first := true
	for instance in meshes:
		var relative := root.global_transform.affine_inverse() * instance.global_transform
		var box := relative * instance.mesh.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result

func _specimen_footprint(meshes: Array[MeshInstance3D]) -> Vector2:
	var bounds := _combined_aabb(_fossil_root, meshes)
	return Vector2(bounds.size.x + margin_m * 2.0, bounds.size.z + margin_m * 2.0)

# --- Gangue -----------------------------------------------------------------

func _build_slab(footprint: Vector2) -> void:
	var columns := maxi(2, int(ceil(footprint.x / cell_size)))
	var rows := maxi(2, int(ceil(footprint.y / cell_size)))
	_slab.build(rock_profile, columns, rows, cell_size)
	_slab.material_override = _build_rock_material()
	# La base de la gangue passe legerement sous le sommet du specimen : une fois
	# la derniere couche retiree, le fossile depasse d'un cheveu au lieu d'affleurer
	# exactement a ras, ce qui le rendrait invisible.
	_slab.position = Vector3(0.0, -protrusion_m, 0.0)

func _build_rock_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	material.set_shader_parameter("base_color", rock_profile.base_color)
	material.set_shader_parameter("accent_color", rock_profile.accent_color)
	material.set_shader_parameter("deep_color", rock_profile.deep_color)
	material.set_shader_parameter("grain_scale", rock_profile.grain_scale)
	material.set_shader_parameter("grain_strength", rock_profile.grain_strength)
	material.set_shader_parameter("mottle_scale", rock_profile.mottle_scale)
	material.set_shader_parameter("mottle_strength", rock_profile.mottle_strength)
	material.set_shader_parameter("lamination_scale", rock_profile.lamination_scale)
	material.set_shader_parameter("lamination_strength", rock_profile.lamination_strength)
	material.set_shader_parameter("rock_roughness", rock_profile.roughness)
	return material

## Ouvre la petite fenetre de depart la ou le fossile est le plus proche de la
## surface, comme un specimen qui affleure naturellement sur le terrain.
## La recherche est limitee a la partie centrale de la plaque : le point le plus
## haut d'un scan se trouve souvent sur un bord releve, ce qui donnerait
## l'impression d'un simple eclat de coin plutot que d'une fenetre sur la piece.
func _carve_starting_hint(meshes: Array[MeshInstance3D]) -> void:
	var bounds := _combined_aabb(_fossil_root, meshes)
	var half := Vector2(bounds.size.x, bounds.size.z) * hint_search_area * 0.5
	var centre := Vector2(bounds.get_center().x, bounds.get_center().z)
	var search := Rect2(centre - half, half * 2.0)

	var highest := _highest_point_xz(meshes, search)
	var cell := _slab.local_to_cell(_slab.to_local(Vector3(highest.x, 0.0, highest.y)))
	_slab.carve_disc(cell, hint_radius_cells, hint_remaining_layers)

func _highest_point_xz(meshes: Array[MeshInstance3D], search: Rect2) -> Vector2:
	var best_y := -INF
	var best := search.get_center()
	for instance in meshes:
		var to_scene := global_transform.affine_inverse() * instance.global_transform
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			if arrays.is_empty():
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			# Echantillonnage : inutile de parcourir 500 000 sommets pour situer un point.
			var stride := maxi(1, vertices.size() / 8000)
			var index := 0
			while index < vertices.size():
				var point := to_scene * vertices[index]
				var flat := Vector2(point.x, point.z)
				if point.y > best_y and search.has_point(flat):
					best_y = point.y
					best = flat
				index += stride
	return best

# --- Ambiance ---------------------------------------------------------------

func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.14, 0.12, 0.10)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.59, 0.54)
	environment.ambient_light_energy = 0.85
	# Les scans de musee ont un albedo deja tres clair : sans compression des
	# hautes lumieres, la dalle part en blanc pur.
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.85
	environment.tonemap_white = 4.0

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	# Lumiere principale rasante : c'est ainsi qu'on eclaire une piece en cours de
	# preparation, les reliefs osseux ressortent beaucoup mieux. On compense
	# l'angle faible par une intensite elevee, sinon la face du dessus reste noire.
	_key_light.light_color = Color(1.0, 0.96, 0.88)
	_key_light.light_energy = 2.0
	_key_light.rotation_degrees = Vector3(-34.0, 35.0, 0.0)
	_key_light.shadow_enabled = true

	_fill_light.light_color = Color(0.82, 0.86, 1.0)
	_fill_light.light_energy = 0.45
	_fill_light.rotation_degrees = Vector3(-58.0, -140.0, 0.0)
	_fill_light.shadow_enabled = false

func _build_status_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_status_label = Label.new()
	_status_label.position = Vector2(16.0, 12.0)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82))
	layer.add_child(_status_label)

func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message

func _warn(message: String) -> void:
	push_warning("[Lab] " + message)
	_set_status(message)
