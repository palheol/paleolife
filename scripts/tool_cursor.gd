extends Node3D
class_name ToolCursor

## Remplace le pointeur de la souris par l'outil en main, pose sur la plaque.
##
## Les trois modeles arrivent avec des echelles et des orientations sans rapport
## entre elles (le stylet mesure 28 unites sur Y, le pinceau 1 sur X, le flacon
## 139 sur Y). On ne fige donc rien : chaque outil est mesure a l'import, mis a
## l'echelle voulue, et oriente d'apres son axe le plus long.

## Inclinaison de l'outil : 0 = couche sur la plaque, 1 = tenu presque vertical.
@export_range(0.0, 1.0, 0.05) var uprightness: float = 0.62
## Noms de noeuds a masquer dans les modeles (marques deposees visibles).
@export var hidden_node_names: PackedStringArray = PackedStringArray(["Logo"])

@export_group("Micro-percuteur")
@export var percuteur_model: String = "res://3D models/PEN.glb"
@export var percuteur_length_m: float = 0.17
@export var percuteur_flip: bool = false

@export_group("Pinceau")
@export var pinceau_model: String = "res://3D models/BRUSH.glb"
@export var pinceau_length_m: float = 0.19
@export var pinceau_flip: bool = false

@export_group("Colle")
@export var colle_model: String = "res://3D models/GLUE.glb"
@export var colle_length_m: float = 0.12
@export var colle_flip: bool = true
## Le flacon vient d'un STL, donc sans texture : sans teinte il part en
## silhouette blanche surexposee. Alpha a 0 pour laisser le modele tel quel.
@export var colle_tint: Color = Color(0.74, 0.66, 0.5, 1.0)

var _slab: RockSlab
var _camera: Camera3D
var _tools: Dictionary = {}   # Tool -> { node, axis, tip_local, scale }
var _active: Dictionary = {}
var _cursor_hidden: bool = false

func setup(slab: RockSlab, camera: Camera3D) -> void:
	_slab = slab
	_camera = camera
	_load(DigController.Tool.PERCUTEUR, percuteur_model, percuteur_length_m,
		percuteur_flip, Color(0, 0, 0, 0))
	_load(DigController.Tool.PINCEAU, pinceau_model, pinceau_length_m,
		pinceau_flip, Color(0, 0, 0, 0))
	_load(DigController.Tool.COLLE, colle_model, colle_length_m, colle_flip, colle_tint)

func show_tool(tool: DigController.Tool) -> void:
	for key in _tools:
		var entry: Dictionary = _tools[key]
		(entry["node"] as Node3D).visible = false
	_active = _tools.get(tool, {})

func _load(tool: DigController.Tool, path: String, target_length: float, flip: bool,
		tint: Color) -> void:
	if not ResourceLoader.exists(path):
		push_warning("[ToolCursor] Modele d'outil introuvable : %s" % path)
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var node := packed.instantiate() as Node3D
	add_child(node)
	node.visible = false
	_hide_marked_nodes(node)
	if tint.a > 0.0:
		_apply_tint(node, tint)

	# L'axe du manche est cherche par analyse en composantes principales, et non
	# d'apres la boite englobante : ces modeles sont parfois ranges de biais
	# (le stylet l'est), auquel cas la boite ne dit plus rien de leur direction.
	var points := _sample_points(node, 4000)
	if points.size() < 32:
		return

	var centroid := Vector3.ZERO
	for point in points:
		centroid += point
	centroid /= float(points.size())

	var axis := _dominant_axis(points, centroid)

	# Longueur et position de la pointe mesurees le long de cet axe.
	var lowest := INF
	var highest := -INF
	for point in points:
		var along := (point - centroid).dot(axis)
		lowest = minf(lowest, along)
		highest = maxf(highest, along)
	var length := highest - lowest
	if length <= 0.0:
		return

	var factor := target_length / length
	node.scale = Vector3.ONE * factor

	# L'outil doit partir du point de contact et s'elever. On retient donc comme
	# pointe l'extremite opposee a la direction vers laquelle il pointera, et
	# "flip" retourne reellement l'outil au lieu de simplement changer d'extremite
	# (sans cela le flacon de colle se plantait dans la plaque).
	var direction := axis
	var tip_along := lowest
	if flip:
		direction = -axis
		tip_along = highest
	var tip := centroid + axis * tip_along

	_tools[tool] = {
		"node": node,
		"axis": direction,
		"tip_local": tip * factor,
		"scale": factor,
	}

## Direction dans laquelle le nuage de points s'etire le plus : le manche.
func _dominant_axis(points: PackedVector3Array, centroid: Vector3) -> Vector3:
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

	# Iteration de la puissance : converge vers le vecteur propre dominant.
	var axis := Vector3(0.41, 0.57, 0.71).normalized()
	for iteration in 48:
		axis = covariance * axis
		if axis.length() < 0.000001:
			return Vector3.UP
		axis = axis.normalized()
	return axis

func _sample_points(root: Node3D, wanted: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	var instances: Array[MeshInstance3D] = []
	for node in _descendants(root):
		var instance := node as MeshInstance3D
		if instance != null and instance.mesh != null and instance.visible:
			instances.append(instance)
	for instance in instances:
		var relative := root.global_transform.affine_inverse() * instance.global_transform
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			if arrays.is_empty():
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var stride := maxi(1, vertices.size() * instances.size() / maxi(1, wanted))
			var index := 0
			while index < vertices.size():
				points.append(relative * vertices[index])
				index += stride
	return points

func _apply_tint(root: Node3D, tint: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.38
	for node in _descendants(root):
		var instance := node as MeshInstance3D
		if instance != null:
			instance.material_override = material

func _hide_marked_nodes(root: Node) -> void:
	for child in root.get_children():
		var node_name := String(child.name)
		for fragment in hidden_node_names:
			if not fragment.is_empty() and node_name.contains(fragment):
				var visual := child as Node3D
				if visual != null:
					visual.visible = false
		_hide_marked_nodes(child)

func _combined_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in _descendants(root):
		var instance := node as MeshInstance3D
		if instance == null or instance.mesh == null or not instance.visible:
			continue
		var relative := root.global_transform.affine_inverse() * instance.global_transform
		var box := relative * instance.mesh.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result

func _descendants(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in root.get_children():
		found.append(child)
		found.append_array(_descendants(child))
	return found

func _process(_delta: float) -> void:
	if _active.is_empty() or _camera == null or _slab == null:
		return
	var node := _active["node"] as Node3D

	# Au-dessus de l'interface, on rend la main au pointeur systeme.
	if get_viewport().gui_get_hovered_control() != null:
		node.visible = false
		_set_system_cursor(true)
		return

	var contact: Variant = _contact_point()
	if contact == null:
		node.visible = false
		_set_system_cursor(true)
		return

	node.visible = true
	_set_system_cursor(false)
	_place(node, contact as Vector3)

## Point vise sur la plaque. Le lancer de rayon traverse les cellules deja
## degagees, d'ou le repli sur un plan horizontal : sans lui, l'outil
## disparaitrait justement au-dessus des zones sur lesquelles on travaille.
func _contact_point() -> Variant:
	var mouse := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse)
	var direction := _camera.project_ray_normal(mouse)

	var hit := _slab.raycast(origin, direction)
	if hit.get("hit", false):
		return hit["position"]

	var level := _slab.global_position.y + _slab.max_top()
	var plane := Plane(Vector3.UP, level)
	var fallback: Variant = plane.intersects_ray(origin, direction)
	if fallback == null:
		return null
	return fallback

func _place(node: Node3D, contact: Vector3) -> void:
	# L'outil penche surtout sur le cote, comme tenu en main, et un peu vers
	# l'observateur. Le faire pencher droit vers la camera le montrerait en fort
	# raccourci : on ne verrait qu'un bout, et sa longueur deviendrait illisible.
	var towards_camera := _camera.global_position - contact
	towards_camera.y = 0.0
	if towards_camera.length_squared() < 0.000001:
		towards_camera = Vector3.BACK
	towards_camera = towards_camera.normalized()
	var sideways := Vector3(-towards_camera.z, 0.0, towards_camera.x)
	var horizontal := (sideways * 0.85 + towards_camera * 0.3).normalized()
	var lean := (horizontal * (1.0 - uprightness)
		+ Vector3.UP * maxf(uprightness, 0.05)).normalized()

	var axis: Vector3 = _active["axis"]
	var tip_local: Vector3 = _active["tip_local"]
	var factor: float = _active["scale"]
	var basis := Basis(Quaternion(axis, lean))
	node.global_transform = Transform3D(
		basis.scaled(Vector3.ONE * factor),
		contact - basis * tip_local)

func _set_system_cursor(visible_cursor: bool) -> void:
	if visible_cursor == not _cursor_hidden:
		return
	_cursor_hidden = not visible_cursor
	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE if visible_cursor else Input.MOUSE_MODE_HIDDEN)

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
