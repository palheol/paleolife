extends Node
class_name DigController

## Degagement du fossile au clic gauche, selon la mecanique validee en maquette
## (voir maquette/fouille_labo.html et GDD §3.2) :
##   - micro-percuteur : retire la roche en vrac, mais un geste ample et rapide
##     fait grimper le risque de fissure ;
##   - pinceau : derniere couche, finition, jamais de risque ;
##   - colle : recolle une fissure. La valeur scientifique perdue, elle, ne
##     revient pas (pas de perte definitive, mais un vrai malus).

enum Tool { PERCUTEUR, PINCEAU, COLLE }

signal risk_changed(ratio: float)
signal stats_changed(cleared: float, science_value: float, crack_count: int)
signal tool_changed(tool: Tool)
signal cracked()

## Rayon d'action des outils, en cellules.
@export var percuteur_radius: int = 2
@export var pinceau_radius: int = 2
## Vitesse a laquelle le risque retombe quand on ralentit (par seconde).
@export var risk_recovery: float = 0.55
## Malus de valeur scientifique par fissure, et plancher.
@export var crack_penalty: float = 8.0
@export var minimum_science_value: float = 40.0
## Tolerance de visee, en pixels, pour recoller une fissure d'un clic.
@export var glue_reach_px: float = 45.0

var current_tool: Tool = Tool.PERCUTEUR
var risk: float = 0.0
var science_value: float = 100.0

var _slab: RockSlab
var _camera: Camera3D
var _cracks_root: Node3D
var _mask: PackedByteArray = PackedByteArray()
var _crack_positions: PackedVector3Array = PackedVector3Array()
var _crack_nodes: Array[Node3D] = []
var _pressing: bool = false
var _last_screen: Vector2 = Vector2.ZERO
var _last_motion_ms: int = 0
## Dernier point de roche reellement entame : c'est la qu'apparait une fissure.
## Relancer un rayon au moment de la casse ne marcherait pas, puisqu'il
## traverserait le creux qu'on vient d'ouvrir.
var _last_dig_position: Vector3 = Vector3.ZERO
var _has_dug: bool = false

func setup(slab: RockSlab, camera: Camera3D, cracks_root: Node3D, mask: PackedByteArray) -> void:
	_slab = slab
	_camera = camera
	_cracks_root = cracks_root
	_mask = mask
	_emit_stats()

func select_tool(tool: Tool) -> void:
	current_tool = tool
	tool_changed.emit(tool)

func _process(delta: float) -> void:
	if risk <= 0.0:
		return
	# Prendre son temps fait retomber le risque : c'est le levier du joueur.
	risk = maxf(0.0, risk - risk_recovery * delta)
	risk_changed.emit(risk)

func _unhandled_input(event: InputEvent) -> void:
	if _slab == null or _camera == null:
		return

	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_pressing = button.pressed
		if button.pressed:
			_last_screen = button.position
			_last_motion_ms = Time.get_ticks_msec()
			if current_tool == Tool.COLLE:
				_try_glue(button.position)
			else:
				_apply_at(button.position)
		return

	var motion := event as InputEventMouseMotion
	if motion == null or not _pressing or current_tool == Tool.COLLE:
		return

	var now := Time.get_ticks_msec()
	var elapsed := maxi(1, now - _last_motion_ms)
	var travel := motion.position.distance_to(_last_screen)

	# Le risque depend a la fois de l'amplitude du geste et de sa vitesse :
	# un grand trait rapide au percuteur est bien plus dangereux qu'un petit
	# mouvement lent, meme s'ils retirent la meme quantite de roche.
	if current_tool == Tool.PERCUTEUR:
		var speed := travel / float(elapsed)
		risk = minf(1.0, risk + clampf(travel * 0.0022 + speed * 0.075, 0.0, 0.35))
		risk_changed.emit(risk)

	# On repasse par les points intermediaires, sinon un geste rapide laisserait
	# des trous entre deux evenements de souris.
	var steps := clampi(int(travel / 6.0), 1, 12)
	for step in range(1, steps + 1):
		_apply_at(_last_screen.lerp(motion.position, float(step) / float(steps)))

	_last_screen = motion.position
	_last_motion_ms = now

	if risk >= 1.0:
		_add_crack()

func _apply_at(screen_position: Vector2) -> void:
	var result := _raycast(screen_position)
	if not result.get("hit", false):
		return
	var cell: Vector2i = result["cell"]
	var radius := percuteur_radius if current_tool == Tool.PERCUTEUR else pinceau_radius
	var changed := false

	for row in range(cell.y - radius, cell.y + radius + 1):
		for col in range(cell.x - radius, cell.x + radius + 1):
			if Vector2(col - cell.x, row - cell.y).length() > float(radius):
				continue
			var layers := _slab.get_layers_at(col, row)
			if current_tool == Tool.PERCUTEUR:
				# Le percuteur degrossit mais ne touche pas a la derniere couche :
				# la finition revient au pinceau.
				if layers > 1:
					_slab.set_layers_at(col, row, layers - 1)
					changed = true
			elif layers == 1:
				_slab.set_layers_at(col, row, 0)
				changed = true

	if changed:
		_last_dig_position = result["position"]
		_has_dug = true
		_emit_stats()

func _raycast(screen_position: Vector2) -> Dictionary:
	var from := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	return _slab.raycast(from, direction)

func _add_crack() -> void:
	risk = 0.0
	risk_changed.emit(risk)
	if not _has_dug:
		return

	var position := _last_dig_position
	_crack_positions.append(position)
	science_value = maxf(minimum_science_value, science_value - crack_penalty)
	if _cracks_root != null:
		var node := _build_crack_mesh(position)
		_cracks_root.add_child(node)
		_crack_nodes.append(node)
	cracked.emit()
	_emit_stats()

## Trace de fissure : une ligne brisee, plus lisible qu'un simple point.
func _build_crack_mesh(position: Vector3) -> MeshInstance3D:
	var immediate := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.18, 0.06, 0.05)
	material.vertex_color_use_as_albedo = false

	immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	var angle := randf() * TAU
	var point := Vector3.ZERO
	immediate.surface_add_vertex(point)
	for segment in 6:
		angle += randf_range(-0.7, 0.7)
		point += Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.002, 0.004)
		immediate.surface_add_vertex(point)
	immediate.surface_end()

	var instance := MeshInstance3D.new()
	instance.mesh = immediate
	# Legerement au-dessus de la roche, sinon la ligne se noie dans la surface.
	instance.position = position + Vector3.UP * 0.0004
	return instance

## On vise la fissure a l'ecran plutot qu'en projetant un rayon sur la roche :
## une fois la zone degagee, un rayon traverserait le creux sans rien toucher.
func _try_glue(screen_position: Vector2) -> void:
	var best := -1
	var best_distance := glue_reach_px
	for index in _crack_positions.size():
		var crack := _crack_positions[index]
		if _camera.is_position_behind(crack):
			continue
		var distance := _camera.unproject_position(crack).distance_to(screen_position)
		if distance < best_distance:
			best_distance = distance
			best = index
	if best < 0:
		return
	_crack_positions.remove_at(best)
	var node := _crack_nodes.pop_at(best) as Node3D
	if node != null:
		node.queue_free()
	_emit_stats()

func _emit_stats() -> void:
	if _slab == null:
		return
	stats_changed.emit(_slab.cleared_ratio(_mask), science_value, _crack_positions.size())
