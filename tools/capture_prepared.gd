extends SceneTree

## Degage une zone puis enregistre une capture, pour juger le rendu d'une
## preparation en cours sans ouvrir l'editeur. La zone est volontairement
## coupee en deux : a gauche on s'arrete au percuteur (il reste le voile de
## poussiere), a droite on finit au pinceau. Deux fissures sont ajoutees, dont
## une recollee, pour controler leur lisibilite.
##
## Usage : godot --path . --script res://tools/capture_prepared.gd -- <sortie.png>

var _frames := 0
var _lab: Node
var _output := "res://capture_prepared.png"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_output = args[0]
	_lab = (load("res://scenes/lab.tscn") as PackedScene).instantiate()
	root.add_child(_lab)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 12:
		_prepare()
		return false
	if _frames < 22:
		return false
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(_output)
		print("capture -> ", _output)
	return true

func _prepare() -> void:
	var dig := _lab.get_node("DigController") as DigController
	var camera := _lab.get_node("OrbitCamera") as Camera3D
	var centre := Vector2(root.size) * 0.5

	var everything: Array[Vector2] = []
	var finished: Array[Vector2] = []
	for row in range(-18, 19):
		for col in range(-26, 27):
			var point := Vector2(float(col) * 5.5, float(row) * 5.5)
			# Contour irregulier : une zone degagee a la main n'est jamais un rectangle.
			if point.length() >= 120.0 + sin(float(col) * 0.7) * 22.0:
				continue
			everything.append(centre + point)
			if col > 0:
				finished.append(centre + point)

	dig.select_tool(DigController.Tool.PERCUTEUR)
	for point in everything:
		dig._apply_at(point)
	dig.select_tool(DigController.Tool.PINCEAU)
	for point in finished:
		dig._apply_at(point)

	# Une fissure laissee telle quelle, une seconde recollee.
	dig.select_tool(DigController.Tool.PERCUTEUR)
	dig._apply_at(centre + Vector2(60.0, -40.0))
	dig.risk = 1.0
	dig._add_crack()

	dig._apply_at(centre + Vector2(45.0, 55.0))
	dig.risk = 1.0
	dig._add_crack()
	if dig._crack_positions.size() > 0:
		var last: Vector3 = dig._crack_positions[dig._crack_positions.size() - 1]
		dig.select_tool(DigController.Tool.COLLE)
		dig._try_glue(camera.unproject_position(last))
