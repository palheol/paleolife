extends SceneTree

## Outil de developpement : charge une scene, laisse passer quelques images puis
## enregistre une capture PNG. Sert a verifier un rendu 3D sans ouvrir l'editeur.
##
## Usage :
##   godot --path . --script res://tools/capture_scene.gd -- <scene> <sortie.png> [images] [noeud_a_masquer]

var _frames_left: int = 30
var _output: String = "res://capture.png"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := "res://scenes/lab.tscn"
	if args.size() > 0:
		scene_path = args[0]
	if args.size() > 1:
		_output = args[1]
	if args.size() > 2:
		_frames_left = int(args[2])

	var packed := load(scene_path) as PackedScene
	if packed == null:
		printerr("Scene introuvable : ", scene_path)
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)

	# Permet d'inspecter ce qui se cache sous un element (ex. la gangue).
	if args.size() > 3:
		var hidden := instance.find_child(args[3], true, false) as CanvasItem
		var hidden_3d := instance.find_child(args[3], true, false) as Node3D
		if hidden_3d != null:
			hidden_3d.visible = false
		elif hidden != null:
			hidden.visible = false
		else:
			printerr("Noeud a masquer introuvable : ", args[3])

func _process(_delta: float) -> bool:
	_frames_left -= 1
	if _frames_left > 0:
		return false
	var image := root.get_texture().get_image()
	if image == null:
		printerr("Aucune image rendue (mode headless ?)")
		return true
	var error := image.save_png(_output)
	if error != OK:
		printerr("Echec de l'enregistrement : ", error)
	else:
		print("capture -> ", _output, " (", image.get_width(), "x", image.get_height(), ")")
	return true
