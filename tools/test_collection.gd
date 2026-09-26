extends SceneTree

## Verifie que la collection est bien peuplee et qu'on peut changer de piece
## sans recharger la scene. Enregistre une capture de la piece choisie.
## Usage : godot --path . --script res://tools/test_collection.gd -- <sortie.png> [index]

var _frames := 0
var _lab: Node
var _output := "res://collection.png"
var _wanted := 1
var _switched := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_output = args[0]
	if args.size() > 1:
		_wanted = int(args[1])
	_lab = (load("res://scenes/lab.tscn") as PackedScene).instantiate()
	root.add_child(_lab)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		var catalogue := FossilLibrary.all_fossils()
		print("collection : ", catalogue.size(), " pieces")
		for entry in catalogue:
			var site := FossilLibrary.site_for(entry)
			var origin := "inconnue" if site == null else site.site_name
			var profile := FossilLibrary.profile_for(entry)
			print("  ", entry.id, " -> ", origin,
				" | roche=", "aucune" if profile == null else profile.site_id,
				" | modele=", "absent" if not ResourceLoader.exists(entry.model_path) else "present")
		if _wanted < catalogue.size():
			print("changement vers : ", catalogue[_wanted].id)
			_lab.load_fossil(catalogue[_wanted])
			_switched = true
		return false
	if _frames < 26:
		return false
	if not _switched:
		printerr("Aucun changement effectue.")
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(_output)
		print("capture -> ", _output)
	return true
