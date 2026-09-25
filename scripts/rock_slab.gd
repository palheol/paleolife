extends MeshInstance3D
class_name RockSlab

## Plaque de gangue generee par code, posee au-dessus du specimen scanne.
## Chaque cellule retient un nombre de couches ; retirer une couche fait
## descendre sa face superieure (degagement couche par couche, GDD §3.2).
##
## Le maillage est organise en "cases" de taille fixe : chaque cellule possede
## toujours 30 sommets reserves (1 dessus + 4 parois), les triangles inutiles
## etant degeneres. Creuser ne reecrit donc que la cellule touchee et ses quatre
## voisines, au lieu de reconstruire toute la plaque a chaque coup d'outil.

signal rebuilt

const VERTS_PER_CELL: int = 30

var profile: RockProfile
var columns: int = 1
var rows: int = 1
var cell_size: float = 0.005

var _layers: PackedInt32Array = PackedInt32Array()
## Altitude du dessous de la gangue pour chaque cellule : elle epouse le relief
## du specimen, de sorte que la roche l'habille au lieu de le recouvrir a plat.
var _bases: PackedFloat32Array = PackedFloat32Array()
var _positions: PackedVector3Array = PackedVector3Array()
var _normals: PackedVector3Array = PackedVector3Array()
var _colors: PackedColorArray = PackedColorArray()
var _floor_level: float = 0.0
var _max_top: float = 0.0
var _dirty: bool = false

func _process(_delta: float) -> void:
	# Les coups d'outil marquent la plaque comme sale ; on ne renvoie le maillage
	# a la carte graphique qu'une fois par image, meme si plusieurs cellules ont bouge.
	if _dirty:
		_dirty = false
		_upload()

func build(rock_profile: RockProfile, grid_columns: int, grid_rows: int, size_of_cell: float,
		base_heights: PackedFloat32Array) -> void:
	profile = rock_profile
	columns = maxi(1, grid_columns)
	rows = maxi(1, grid_rows)
	cell_size = size_of_cell

	var count := columns * rows
	_layers = PackedInt32Array()
	_layers.resize(count)
	_layers.fill(profile.layer_count)

	_bases = base_heights
	if _bases.size() != count:
		_bases = PackedFloat32Array()
		_bases.resize(count)
		_bases.fill(0.0)

	_floor_level = INF
	_max_top = -INF
	for base in _bases:
		_floor_level = minf(_floor_level, base)
		_max_top = maxf(_max_top, base + surface_thickness())
	_floor_level -= 0.004

	var total := count * VERTS_PER_CELL + 6 # +6 : face inferieure
	_positions.resize(total)
	_normals.resize(total)
	_colors.resize(total)

	for row in rows:
		for col in columns:
			_write_cell(col, row)
	_write_bottom()
	_upload()

func size_x() -> float:
	return float(columns) * cell_size

func size_z() -> float:
	return float(rows) * cell_size

## Epaisseur totale de gangue au-dessus du specimen.
func surface_thickness() -> float:
	return float(profile.layer_count) * profile.layer_height

## Altitude du point le plus haut de la plaque intacte.
func max_top() -> float:
	return _max_top

## Altitude du dessus d'une cellule (base locale + couches restantes).
func cell_top(col: int, row: int) -> float:
	if not is_inside(col, row):
		return _floor_level
	var index := row * columns + col
	return _bases[index] + float(_layers[index]) * profile.layer_height

func get_layers_at(col: int, row: int) -> int:
	# Hors grille : 0, ce qui fait naturellement apparaitre les flancs du bloc.
	if col < 0 or col >= columns or row < 0 or row >= rows:
		return 0
	return _layers[row * columns + col]

func set_layers_at(col: int, row: int, value: int) -> void:
	if col < 0 or col >= columns or row < 0 or row >= rows:
		return
	var clamped := clampi(value, 0, profile.layer_count)
	if _layers[row * columns + col] == clamped:
		return
	_layers[row * columns + col] = clamped
	# La cellule et ses voisines : leurs parois mitoyennes changent aussi.
	_write_cell(col, row)
	_write_cell(col - 1, row)
	_write_cell(col + 1, row)
	_write_cell(col, row - 1)
	_write_cell(col, row + 1)
	_dirty = true

## Retire une couche sur une cellule. Renvoie true si quelque chose a bouge.
func dig(col: int, row: int) -> bool:
	var before := get_layers_at(col, row)
	if before <= 0:
		return false
	set_layers_at(col, row, before - 1)
	return true

## Creuse un disque de cellules, moins profond sur les bords pour un aspect erode.
func carve_disc(center: Vector2i, radius_cells: int, remaining_at_center: int) -> void:
	var deepest := float(profile.layer_count - remaining_at_center)
	for row in range(center.y - radius_cells, center.y + radius_cells + 1):
		for col in range(center.x - radius_cells, center.x + radius_cells + 1):
			var distance := Vector2(col - center.x, row - center.y).length()
			if distance > float(radius_cells):
				continue
			var t := distance / maxf(1.0, float(radius_cells))
			var depth := int(round(lerpf(deepest, 1.0, t * t)))
			set_layers_at(col, row, profile.layer_count - depth)

func local_to_cell(local_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor((local_pos.x + size_x() * 0.5) / cell_size)),
		int(floor((local_pos.z + size_z() * 0.5) / cell_size)))

## Centre du dessus d'une cellule, en coordonnees locales.
func cell_to_local(col: int, row: int) -> Vector3:
	return Vector3(
		(float(col) + 0.5) * cell_size - size_x() * 0.5,
		cell_top(col, row),
		(float(row) + 0.5) * cell_size - size_z() * 0.5)

func is_inside(col: int, row: int) -> bool:
	return col >= 0 and col < columns and row >= 0 and row < rows

## Cherche la premiere cellule touchee par un rayon (repere global).
## On avance le long du rayon par petits pas plutot que de resoudre l'intersection
## analytiquement : la grille peut avoir un dessous irregulier, et quelques
## centaines de pas restent negligeables pour un clic.
func raycast(from_global: Vector3, direction_global: Vector3) -> Dictionary:
	var miss := {"hit": false, "cell": Vector2i.ZERO, "position": Vector3.ZERO}
	var origin := to_local(from_global)
	var direction := (global_transform.basis.inverse() * direction_global).normalized()
	if direction.length_squared() < 0.5:
		return miss

	var bounds := AABB(
		Vector3(-size_x() * 0.5, _floor_level, -size_z() * 0.5),
		Vector3(size_x(), _max_top - _floor_level, size_z()))
	# Marge : un rayon rasant peut entrer tout juste au bord de l'emprise.
	bounds = bounds.grow(cell_size)
	if not bounds.intersects_ray(origin, direction) and not bounds.has_point(origin):
		return miss

	var step := cell_size * 0.4
	var travelled := 0.0
	var limit := (bounds.size.length() + origin.length()) * 2.0
	while travelled < limit:
		var point := origin + direction * travelled
		travelled += step
		if point.y > _max_top + cell_size:
			continue
		if point.y < _floor_level:
			return miss
		var cell := local_to_cell(point)
		if not is_inside(cell.x, cell.y):
			continue
		if _layers[cell.y * columns + cell.x] <= 0:
			continue # cellule deja degagee : le rayon passe au travers
		if point.y <= cell_top(cell.x, cell.y):
			return {"hit": true, "cell": cell, "position": to_global(point)}
	return miss

## Proportion de cellules entierement degagees parmi celles qui comptent.
func cleared_ratio(mask: PackedByteArray) -> float:
	var total := 0
	var cleared := 0
	for index in _layers.size():
		if index < mask.size() and mask[index] == 0:
			continue
		total += 1
		if _layers[index] == 0:
			cleared += 1
	if total == 0:
		return 0.0
	return float(cleared) / float(total)

# --- Construction du maillage ------------------------------------------------

func _upload() -> void:
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = _positions
	surface[Mesh.ARRAY_NORMAL] = _normals
	surface[Mesh.ARRAY_COLOR] = _colors
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	mesh = array_mesh
	rebuilt.emit()

func _write_cell(col: int, row: int) -> void:
	if not is_inside(col, row):
		return
	var slot := (row * columns + col) * VERTS_PER_CELL
	var height := _layers[row * columns + col]
	var max_layers := float(maxi(1, profile.layer_count))

	var x0 := float(col) * cell_size - size_x() * 0.5
	var z0 := float(row) * cell_size - size_z() * 0.5
	var x1 := x0 + cell_size
	var z1 := z0 + cell_size
	var y := cell_top(col, row)
	var shade := Color(float(height) / max_layers, 0.0, 0.0)

	# Une cellule entierement degagee ne dessine plus de dessus : c'est ce qui
	# laisse apparaitre le specimen en dessous.
	if height > 0:
		_write_quad(slot,
			Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0),
			Vector3.UP, shade, shade, shade, shade)
	else:
		_write_degenerate(slot)

	_write_wall(slot + 6, col, row, y, shade, -1, 0, x0, z0, x0, z1, Vector3.LEFT, max_layers)
	_write_wall(slot + 12, col, row, y, shade, 1, 0, x1, z1, x1, z0, Vector3.RIGHT, max_layers)
	_write_wall(slot + 18, col, row, y, shade, 0, -1, x1, z0, x0, z0, Vector3.FORWARD, max_layers)
	_write_wall(slot + 24, col, row, y, shade, 0, 1, x0, z1, x1, z1, Vector3.BACK, max_layers)

func _write_wall(slot: int, col: int, row: int, y_top: float, c_top: Color, dx: int, dz: int,
		ax: float, az: float, bx: float, bz: float, normal: Vector3, max_layers: float) -> void:
	var neighbour_top := cell_top(col + dx, row + dz)
	if neighbour_top >= y_top:
		_write_degenerate(slot)
		return
	# Degrade du bas vers le haut : les couches se lisent sur la tranche.
	var neighbour_layers := get_layers_at(col + dx, row + dz)
	var c_bottom := Color(float(neighbour_layers) / max_layers, 0.0, 0.0)
	_write_quad(slot,
		Vector3(ax, neighbour_top, az), Vector3(ax, y_top, az),
		Vector3(bx, y_top, bz), Vector3(bx, neighbour_top, bz),
		normal, c_bottom, c_top, c_top, c_bottom)

func _write_bottom() -> void:
	var slot := columns * rows * VERTS_PER_CELL
	var half_x := size_x() * 0.5
	var half_z := size_z() * 0.5
	var dark := Color(0.0, 0.0, 0.0)
	_write_quad(slot,
		Vector3(-half_x, _floor_level, -half_z), Vector3(half_x, _floor_level, -half_z),
		Vector3(half_x, _floor_level, half_z), Vector3(-half_x, _floor_level, half_z),
		Vector3.DOWN, dark, dark, dark, dark)

func _write_quad(base: int, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		normal: Vector3, c0: Color, c1: Color, c2: Color, c3: Color) -> void:
	_positions[base] = p0
	_positions[base + 1] = p1
	_positions[base + 2] = p2
	_positions[base + 3] = p0
	_positions[base + 4] = p2
	_positions[base + 5] = p3
	for offset in 6:
		_normals[base + offset] = normal
	_colors[base] = c0
	_colors[base + 1] = c1
	_colors[base + 2] = c2
	_colors[base + 3] = c0
	_colors[base + 4] = c2
	_colors[base + 5] = c3

## Triangles d'aire nulle : la carte graphique les ecarte, ce qui permet de
## garder un emplacement de taille fixe par cellule.
func _write_degenerate(base: int) -> void:
	for offset in 6:
		_positions[base + offset] = Vector3.ZERO
		_normals[base + offset] = Vector3.UP
		_colors[base + offset] = Color.BLACK
