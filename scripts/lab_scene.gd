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
@export var cell_size: float = 0.005
## Marge de gangue autour du specimen, en metres.
@export var margin_m: float = 0.015
## Jeu entre le dessous de la gangue et le specimen. Assez grand pour absorber
## l'erreur residuelle du filtrage, assez petit pour que le fossile apparaisse
## juste sous l'ouverture une fois la derniere couche retiree.
@export var clearance_m: float = 0.0022

## A quel point la gangue epouse le relief du specimen (0 = dalle plate posee
## dessus, 1 = la roche l'habille exactement).
## Le drapé n'est pas cosmetique : avec une base plate, seul le point le plus
## haut du specimen touche la gangue et degager n'ouvre qu'une cavite vide.
@export_range(0.0, 1.0, 0.05) var relief_follow: float = 0.35
## Profondeur maximale, en metres, sur laquelle la gangue suit le relief. Les
## scans incluent souvent les flancs et le support du bloc : sans cette limite,
## la roche plongerait de 20 cm la ou la face utile s'arrete.
@export var max_drape_depth_m: float = 0.012

@export_group("Indice de depart")
## Petite zone deja erodee qui laisse deviner ou commencer (comme un fossile
## qui affleure naturellement sur le terrain).
@export var hint_radius_cells: int = 6
@export var hint_remaining_layers: int = 0
## Fraction centrale de la plaque ou chercher le point d'affleurement (0.6 = 60 %).
@export_range(0.1, 1.0, 0.05) var hint_search_area: float = 0.55

@export_group("Import du scan")
## Fragments de noms de noeuds a ignorer dans le GLB (objets parasites Sketchfab).
@export var excluded_node_names: PackedStringArray = PackedStringArray(["Cube"])
## Redresse la dalle scannee a l'horizontale. Les scans de musee arrivent dans
## une orientation quelconque, et une plaque inclinee rend la gangue inexploitable.
@export var level_specimen: bool = true
## Les scans de musee sont photographies sous un eclairage de studio, deja cuit
## dans la texture. Sans correction, la piece degagee part en blanc pur.
@export_range(0.1, 1.5, 0.05) var specimen_brightness: float = 0.5
## Teinte appliquee aux modeles sans materiau (un .obj converti, par exemple),
## qui seraient sinon rendus en blanc pur.
@export var untextured_specimen_color: Color = Color(0.34, 0.31, 0.26)

@onready var _slab: RockSlab = $RockSlab
@onready var _fossil_root: Node3D = $FossilRoot
@onready var _camera: OrbitCamera = $OrbitCamera
@onready var _key_light: DirectionalLight3D = $KeyLight
@onready var _fill_light: DirectionalLight3D = $FillLight
@onready var _cracks: Node3D = $Cracks
@onready var _dig: DigController = $DigController
@onready var _ui: LabUI = $LabUI
@onready var _tool_cursor: ToolCursor = $ToolCursor

## Altitude du specimen sous chaque cellule de la grille, et masque des cellules
## qui le recouvrent reellement (le reste n'est que de la marge).
var _specimen_top: PackedFloat32Array = PackedFloat32Array()
var _specimen_mask: PackedByteArray = PackedByteArray()

func _ready() -> void:
	_build_lighting()
	_connect_ui()

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

	_build_slab(_specimen_footprint(meshes), meshes)
	_carve_starting_hint()

	_camera.focus_on(
		Vector3(0.0, _slab.position.y + _slab.max_top() * 0.5, 0.0),
		maxf(_slab.size_x(), _slab.size_z()))

	_dig.setup(_slab, _camera, _cracks, _specimen_mask)
	_tool_cursor.setup(_slab, _camera)
	_tool_cursor.show_tool(_dig.current_tool)

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

	# Godot livre un .glb sous forme de scene, mais un .obj sous forme de simple
	# maillage : on accepte les deux pour ne pas dependre du format d'origine.
	var resource := load(fossil.model_path)
	var model: Node3D = null
	if resource is PackedScene:
		model = (resource as PackedScene).instantiate() as Node3D
	elif resource is Mesh:
		var single := MeshInstance3D.new()
		single.mesh = resource
		model = single
	if model == null:
		_warn("Le fichier %s n'est ni une scene ni un maillage exploitable."
			% fossil.model_path)
		return empty
	_fossil_root.add_child(model)

	var meshes := _collect_meshes(model)
	if meshes.is_empty():
		_warn("Aucun maillage exploitable dans %s." % fossil.model_path)
		return empty

	for instance in meshes:
		_ensure_normals(instance)

	if level_specimen:
		_level_specimen(model, meshes)

	var bounds := _combined_aabb(model, meshes)
	var largest := maxf(bounds.size.x, bounds.size.z)
	if largest <= 0.0:
		_warn("Le modele a une emprise horizontale nulle.")
		return empty

	var scale_factor := specimen_size_m / largest
	model.scale = Vector3.ONE * scale_factor

	var scaled := AABB(bounds.position * scale_factor, bounds.size * scale_factor)
	model.position = Vector3(-scaled.get_center().x, -scaled.end.y, -scaled.get_center().z)
	_tone_down_specimen(meshes)
	return meshes

## Certains formats arrivent sans normales (un .obj converti depuis un fichier
## d'impression 3D, par exemple) : le modele est alors rendu uniformement plat.
## On les recalcule plutot que d'imposer un format d'entree.
func _ensure_normals(instance: MeshInstance3D) -> void:
	var mesh := instance.mesh
	if mesh == null:
		return
	var missing := false
	for surface in mesh.get_surface_count():
		if (mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_NORMAL) == 0:
			missing = true
	if not missing:
		return

	var rebuilt := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var builder := SurfaceTool.new()
		builder.create_from(mesh, surface)
		builder.generate_normals()
		rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, builder.commit_to_arrays())
	instance.mesh = rebuilt

## Assombrit le scan sans toucher a la roche, via des surcharges de materiau
## (l'original importe reste intact).
func _tone_down_specimen(meshes: Array[MeshInstance3D]) -> void:
	for instance in meshes:
		for surface in instance.mesh.get_surface_count():
			var source := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null:
				# Modele sans materiau : il serait rendu en blanc pur.
				var plain := StandardMaterial3D.new()
				plain.albedo_color = untextured_specimen_color
				plain.roughness = 0.75
				instance.set_surface_override_material(surface, plain)
				continue
			if is_equal_approx(specimen_brightness, 1.0):
				continue
			var copy := source.duplicate() as BaseMaterial3D
			copy.albedo_color = Color(
				source.albedo_color.r * specimen_brightness,
				source.albedo_color.g * specimen_brightness,
				source.albedo_color.b * specimen_brightness,
				source.albedo_color.a)
			instance.set_surface_override_material(surface, copy)

## Redresse le scan : on ajuste un plan moyen sur ses sommets (analyse en
## composantes principales) et on bascule ce plan a l'horizontale. Sans cela une
## dalle scannee de travers donnerait une gangue en escalier geant.
func _level_specimen(model: Node3D, meshes: Array[MeshInstance3D]) -> void:
	var points := _sample_points(model, meshes, 8000)
	if points.size() < 32:
		return

	var centroid := Vector3.ZERO
	for point in points:
		centroid += point
	centroid /= float(points.size())

	# Matrice de covariance (symetrique) des ecarts au centre de gravite.
	var xx := 0.0
	var xy := 0.0
	var xz := 0.0
	var yy := 0.0
	var yz := 0.0
	var zz := 0.0
	for point in points:
		var d := point - centroid
		xx += d.x * d.x
		xy += d.x * d.y
		xz += d.x * d.z
		yy += d.y * d.y
		yz += d.y * d.z
		zz += d.z * d.z

	var covariance := Basis(Vector3(xx, xy, xz), Vector3(xy, yy, yz), Vector3(xz, yz, zz))
	var normal := _flattest_axis(covariance)
	if normal.dot(Vector3.UP) < 0.0:
		normal = -normal
	if normal.is_equal_approx(Vector3.UP):
		return
	model.transform = Transform3D(Basis(Quaternion(normal, Vector3.UP)), Vector3.ZERO) * model.transform

## Direction dans laquelle le nuage de points est le plus aplati : c'est la
## normale du plan moyen, donc celle de la dalle.
func _flattest_axis(covariance: Basis) -> Vector3:
	var trace := covariance.x.x + covariance.y.y + covariance.z.z
	if trace <= 0.0:
		return Vector3.UP
	# En retranchant la covariance a un multiple de l'identite, on inverse l'ordre
	# des valeurs propres : la plus petite devient la plus grande, et une simple
	# iteration de la puissance suffit a la trouver.
	var shifted := Basis(
		Vector3(trace - covariance.x.x, -covariance.x.y, -covariance.x.z),
		Vector3(-covariance.y.x, trace - covariance.y.y, -covariance.y.z),
		Vector3(-covariance.z.x, -covariance.z.y, trace - covariance.z.z))
	var axis := Vector3(0.37, 0.61, 0.70).normalized()
	for iteration in 64:
		axis = shifted * axis
		if axis.length() < 0.000001:
			return Vector3.UP
		axis = axis.normalized()
	return axis

func _sample_points(root: Node3D, meshes: Array[MeshInstance3D], wanted: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	for instance in meshes:
		var relative := root.global_transform.affine_inverse() * instance.global_transform
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			if arrays.is_empty():
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var stride := maxi(1, vertices.size() * meshes.size() / maxi(1, wanted))
			var index := 0
			while index < vertices.size():
				points.append(relative * vertices[index])
				index += stride
	return points

## Tous les MeshInstance3D du modele, sauf ceux dont le nom (ou celui d'un parent)
## contient un fragment exclu. Les exclus sont masques plutot que supprimes.
func _collect_meshes(root: Node3D) -> Array[MeshInstance3D]:
	var kept: Array[MeshInstance3D] = []
	# La racine compte elle aussi : un .obj se charge en un unique maillage, sans
	# hierarchie, contrairement a un .glb.
	var candidates: Array[Node] = [root]
	candidates.append_array(_descendants(root))
	for node in candidates:
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

func _build_slab(footprint: Vector2, meshes: Array[MeshInstance3D]) -> void:
	var columns := maxi(2, int(ceil(footprint.x / cell_size)))
	var rows := maxi(2, int(ceil(footprint.y / cell_size)))
	_slab.position = Vector3.ZERO
	_rasterise_specimen(meshes, columns, rows)
	_slab.build(rock_profile, columns, rows, cell_size, _bases_from_specimen(columns, rows))
	_slab.material_override = _build_rock_material()

## Projette le specimen sur la grille : pour chaque cellule, l'altitude la plus
## haute atteinte par le scan en dessous. Sert a la fois a faire epouser la
## gangue au relief et a savoir quelles cellules recouvrent reellement la piece.
func _rasterise_specimen(meshes: Array[MeshInstance3D], columns: int, rows: int) -> void:
	var count := columns * rows
	_specimen_top = PackedFloat32Array()
	_specimen_top.resize(count)
	_specimen_top.fill(-INF)
	_specimen_mask = PackedByteArray()
	_specimen_mask.resize(count)

	var half_x := float(columns) * cell_size * 0.5
	var half_z := float(rows) * cell_size * 0.5

	for instance in meshes:
		var to_scene := global_transform.affine_inverse() * instance.global_transform
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			if arrays.is_empty():
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var stride := maxi(1, vertices.size() / 60000)
			var index := 0
			while index < vertices.size():
				var point := to_scene * vertices[index]
				index += stride
				var col := int(floor((point.x + half_x) / cell_size))
				var row := int(floor((point.z + half_z) / cell_size))
				if col < 0 or col >= columns or row < 0 or row >= rows:
					continue
				var cell := row * columns + col
				if point.y > _specimen_top[cell]:
					_specimen_top[cell] = point.y
					_specimen_mask[cell] = 1

	# Les cellules sans echantillon (marge autour de la piece) sont ramenees au
	# niveau haut du scan.
	for cell in count:
		if _specimen_top[cell] == -INF:
			_specimen_top[cell] = 0.0

func _bases_from_specimen(columns: int, rows: int) -> PackedFloat32Array:
	# Niveau de reference : la mediane des hauteurs sous lesquelles il y a
	# vraiment du specimen. Se caler sur le maximum du scan serait trompeur, car
	# ce maximum est souvent un bord releve du bloc, loin de la face travaillee.
	var face_level := _median_specimen_level()

	# Tout ce qui s'ecarte trop de ce niveau est ramene dans une fourchette : en
	# dessous ce sont les flancs du bloc, au-dessus des asperites isolees.
	var surface := PackedFloat32Array()
	surface.resize(columns * rows)
	for cell in surface.size():
		if _specimen_mask[cell] == 0:
			surface[cell] = face_level
			continue
		surface[cell] = clampf(_specimen_top[cell],
			face_level - max_drape_depth_m, face_level + max_drape_depth_m)

	# Median puis moyenne : le median ecarte les sommets isoles dus au bruit de
	# photogrammetrie (une moyenne, elle, les etale au lieu de les enlever), et le
	# lissage qui suit donne une roche qui drape au lieu de coller au maillage.
	#
	# On ne cherche volontairement pas a garantir zero traversee : imposer que la
	# gangue reste au-dessus du maximum brut de chaque cellule fait ressurgir
	# chaque asperite du scan sous forme de paroi isolee, ce qui est bien plus
	# laid que les rares eclats d'os qui affleurent. Le jeu vertical ci-dessous
	# absorbe l'essentiel, et un bout d'os qui perce reste plausible.
	_median_filter(surface, columns, rows)
	_smooth(surface, columns, rows, 5)

	var bases := PackedFloat32Array()
	bases.resize(columns * rows)
	for cell in bases.size():
		# 0 = plaque plate au niveau moyen de la face, 1 = la roche epouse le relief.
		bases[cell] = lerpf(face_level, surface[cell], relief_follow) + clearance_m
	return bases

## Hauteur representative de la face travaillee : mediane des cellules qui
## recouvrent reellement le specimen, insensible aux bords releves du bloc.
func _median_specimen_level() -> float:
	var heights: Array[float] = []
	for cell in _specimen_top.size():
		if _specimen_mask[cell] != 0:
			heights.append(_specimen_top[cell])
	if heights.is_empty():
		return 0.0
	heights.sort()
	return heights[heights.size() / 2]

## Filtre median 3x3 : remplace chaque cellule par la valeur centrale de son
## voisinage, ce qui ecarte les valeurs aberrantes sans adoucir les vraies pentes.
func _median_filter(values: PackedFloat32Array, columns: int, rows: int) -> void:
	var source := values.duplicate()
	var window: Array[float] = []
	for row in rows:
		for col in columns:
			window.clear()
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var nx := col + dx
					var nz := row + dz
					if nx < 0 or nx >= columns or nz < 0 or nz >= rows:
						continue
					window.append(source[nz * columns + nx])
			window.sort()
			values[row * columns + col] = window[window.size() / 2]

func _smooth(values: PackedFloat32Array, columns: int, rows: int, passes: int) -> void:
	for pass_index in passes:
		var source := values.duplicate()
		for row in rows:
			for col in columns:
				var total := 0.0
				var samples := 0
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var nx := col + dx
						var nz := row + dz
						if nx < 0 or nx >= columns or nz < 0 or nz >= rows:
							continue
						total += source[nz * columns + nx]
						samples += 1
				values[row * columns + col] = total / float(samples)

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
	material.set_shader_parameter("dust_opacity", rock_profile.dust_opacity)
	return material

## Ouvre la petite fenetre de depart la ou le fossile est le plus proche de la
## surface, comme un specimen qui affleure naturellement sur le terrain.
## La recherche est limitee a la partie centrale de la plaque : le point le plus
## haut d'un scan se trouve souvent sur un bord releve, ce qui donnerait
## l'impression d'un simple eclat de coin plutot que d'une fenetre sur la piece.
func _carve_starting_hint() -> void:
	var columns := _slab.columns
	var rows := _slab.rows
	# Recherche limitee a la partie centrale : le point le plus haut d'un scan se
	# trouve souvent sur un bord releve, ce qui donnerait l'impression d'un simple
	# eclat de coin plutot que d'une fenetre sur la piece.
	var margin_cols := int(float(columns) * (1.0 - hint_search_area) * 0.5)
	var margin_rows := int(float(rows) * (1.0 - hint_search_area) * 0.5)

	var best_height := -INF
	var best_cell := Vector2i(columns / 2, rows / 2)
	for row in range(margin_rows, rows - margin_rows):
		for col in range(margin_cols, columns - margin_cols):
			var cell := row * columns + col
			if _specimen_mask[cell] == 0:
				continue
			if _specimen_top[cell] > best_height:
				best_height = _specimen_top[cell]
				best_cell = Vector2i(col, row)

	_slab.carve_disc(best_cell, hint_radius_cells, hint_remaining_layers)

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

func _connect_ui() -> void:
	_ui.tool_requested.connect(_dig.select_tool)
	_dig.tool_changed.connect(_ui.select_tool)
	_dig.risk_changed.connect(_ui.set_risk)
	_dig.stats_changed.connect(_ui.set_stats)
	_dig.tool_changed.connect(_tool_cursor.show_tool)

func _set_status(message: String) -> void:
	if _ui != null:
		_ui.set_title(message)

func _warn(message: String) -> void:
	push_warning("[Lab] " + message)
	_set_status(message)
