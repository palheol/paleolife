extends MeshInstance3D
class_name RockSlab

## Plaque de gangue generee par code, posee au-dessus du specimen scanne.
## Chaque cellule de la grille retient un nombre de couches restantes ; le
## maillage est reconstruit a chaque modification. C'est le support du
## degagement couche par couche decrit au GDD §3.2.

signal rebuilt

var profile: RockProfile
var columns: int = 1
var rows: int = 1
var cell_size: float = 0.01

var _layers: PackedInt32Array = PackedInt32Array()

func build(rock_profile: RockProfile, grid_columns: int, grid_rows: int, size_of_cell: float) -> void:
	profile = rock_profile
	columns = maxi(1, grid_columns)
	rows = maxi(1, grid_rows)
	cell_size = size_of_cell
	_layers = PackedInt32Array()
	_layers.resize(columns * rows)
	_layers.fill(profile.layer_count)
	rebuild()

func size_x() -> float:
	return float(columns) * cell_size

func size_z() -> float:
	return float(rows) * cell_size

## Hauteur de la surface intacte, en coordonnees locales.
func surface_y() -> float:
	return float(profile.layer_count) * profile.layer_height

func get_layers_at(col: int, row: int) -> int:
	# Hors grille : 0, ce qui fait naturellement apparaitre les flancs du bloc.
	if col < 0 or col >= columns or row < 0 or row >= rows:
		return 0
	return _layers[row * columns + col]

func set_layers_at(col: int, row: int, value: int) -> void:
	if col < 0 or col >= columns or row < 0 or row >= rows:
		return
	_layers[row * columns + col] = clampi(value, 0, profile.layer_count)

## Retire une couche sur une cellule : geste elementaire du micro-percuteur.
func dig(col: int, row: int) -> void:
	set_layers_at(col, row, get_layers_at(col, row) - 1)
	rebuild()

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
	rebuild()

func local_to_cell(local_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor((local_pos.x + size_x() * 0.5) / cell_size)),
		int(floor((local_pos.z + size_z() * 0.5) / cell_size)))

func rebuild() -> void:
	if profile == null:
		return
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)

	var layer_height := profile.layer_height
	var half_x := size_x() * 0.5
	var half_z := size_z() * 0.5
	var max_layers := float(maxi(1, profile.layer_count))

	for row in rows:
		for col in columns:
			var height := _layers[row * columns + col]
			var x0 := float(col) * cell_size - half_x
			var z0 := float(row) * cell_size - half_z
			var x1 := x0 + cell_size
			var z1 := z0 + cell_size
			var y := float(height) * layer_height
			var shade := Color(float(height) / max_layers, 0.0, 0.0)

			if height > 0:
				_quad(builder,
					Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0),
					Vector3.UP, shade, shade, shade, shade)

			_wall(builder, col, row, height, Vector2i(-1, 0), x0, z0, x0, z1, Vector3.LEFT, max_layers)
			_wall(builder, col, row, height, Vector2i(1, 0), x1, z1, x1, z0, Vector3.RIGHT, max_layers)
			_wall(builder, col, row, height, Vector2i(0, -1), x1, z0, x0, z0, Vector3.FORWARD, max_layers)
			_wall(builder, col, row, height, Vector2i(0, 1), x0, z1, x1, z1, Vector3.BACK, max_layers)

	var bottom := Color(0.0, 0.0, 0.0)
	_quad(builder,
		Vector3(-half_x, 0.0, -half_z), Vector3(half_x, 0.0, -half_z),
		Vector3(half_x, 0.0, half_z), Vector3(-half_x, 0.0, half_z),
		Vector3.DOWN, bottom, bottom, bottom, bottom)

	mesh = builder.commit()
	rebuilt.emit()

func _wall(builder: SurfaceTool, col: int, row: int, height: int, offset: Vector2i,
		ax: float, az: float, bx: float, bz: float, normal: Vector3, max_layers: float) -> void:
	var neighbour := get_layers_at(col + offset.x, row + offset.y)
	if neighbour >= height:
		return
	var y_top := float(height) * profile.layer_height
	var y_bottom := float(neighbour) * profile.layer_height
	# Degrade de couleur du bas vers le haut : les couches se lisent sur les flancs.
	var c_top := Color(float(height) / max_layers, 0.0, 0.0)
	var c_bottom := Color(float(neighbour) / max_layers, 0.0, 0.0)
	_quad(builder,
		Vector3(ax, y_bottom, az), Vector3(ax, y_top, az),
		Vector3(bx, y_top, bz), Vector3(bx, y_bottom, bz),
		normal, c_bottom, c_top, c_top, c_bottom)

func _quad(builder: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		normal: Vector3, c0: Color, c1: Color, c2: Color, c3: Color) -> void:
	_vertex(builder, p0, normal, c0)
	_vertex(builder, p1, normal, c1)
	_vertex(builder, p2, normal, c2)
	_vertex(builder, p0, normal, c0)
	_vertex(builder, p2, normal, c2)
	_vertex(builder, p3, normal, c3)

func _vertex(builder: SurfaceTool, p: Vector3, normal: Vector3, c: Color) -> void:
	builder.set_normal(normal)
	builder.set_color(c)
	builder.set_uv(Vector2(p.x, p.z))
	builder.add_vertex(p)
