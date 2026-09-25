extends SceneTree

## Degage une zone puis enregistre une capture, pour juger le rendu
## d'une preparation en cours. Usage :
##   godot --path . --script res://tools/capture_prepared.gd -- <sortie.png>

var _frames := 0
var _lab: Node
var _output := "res://capture_dig.png"

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
	if _frames < 20:
		return false
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(_output)
		print("capture -> ", _output)
	return true

func _prepare() -> void:
	var dig := _lab.get_node("DigController") as DigController
	var centre := Vector2(root.size) * 0.5
	var offsets: Array[Vector2] = []
	for row in range(-18, 19):
		for col in range(-26, 27):
			var point := Vector2(float(col) * 5.5, float(row) * 5.5)
			# Contour irregulier : une zone degagee a la main n'est jamais un rectangle.
			if point.length() < 120.0 + sin(float(col) * 0.7) * 22.0:
				offsets.append(centre + point)

	dig.select_tool(DigController.Tool.PERCUTEUR)
	for point in offsets:
		dig._apply_at(point)
	dig.select_tool(DigController.Tool.PINCEAU)
	for point in offsets:
		dig._apply_at(point)
