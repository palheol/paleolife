extends SceneTree

## Verifie l'aller-retour du trace de zone : on peint, on enregistre, on
## recharge la piece, et le trace doit revenir a l'identique.
## Usage : godot --path . --script res://tools/test_zone.gd

var _frames := 0
var _lab: Node
var _painted := 0

func _initialize() -> void:
	_lab = (load("res://scenes/lab.tscn") as PackedScene).instantiate()
	root.add_child(_lab)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		_paint_and_save()
		return false
	if _frames == 20:
		_verify()
		if OS.get_cmdline_user_args().size() > 0:
			_lab._set_zone_edit_mode(true)
			return false
		return true
	if _frames < 28:
		return false
	var image := root.get_texture().get_image()
	if image != null:
		var target: String = OS.get_cmdline_user_args()[0]
		image.save_png(target)
		print("capture -> ", target)
	return true

func _paint_and_save() -> void:
	var slab := _lab.get_node("RockSlab") as RockSlab
	# On efface tout d'abord, sinon on repartirait de la zone par defaut qui
	# couvre la piece entiere et l'essai ne prouverait rien.
	_lab.paint_zone(Vector2i(slab.columns / 2, slab.rows / 2),
		maxi(slab.columns, slab.rows), false)
	print("apres effacement : ", _count(_lab), " cellules")
	# Un trace simple et reconnaissable : une bande au milieu de la plaque.
	for step in 9:
		_lab.paint_zone(Vector2i(slab.columns / 2, slab.rows / 4 + step * 4), 4, true)
	_painted = _count(_lab)
	print("cellules peintes : ", _painted, " sur ", slab.columns * slab.rows)
	_lab.save_zone_mask()

	var path: String = LabScene.zone_path((_lab.fossil as FossilData).id)
	print("fichier ecrit : ", FileAccess.file_exists(path), " (", path, ")")

func _verify() -> void:
	# Recharger la piece doit relire le trace depuis le disque.
	_lab.load_fossil(_lab.fossil)
	var reloaded := _count(_lab)
	print("cellules relues : ", reloaded)
	var drift := absf(float(reloaded - _painted) / float(maxi(1, _painted)))
	if drift > 0.05:
		printerr("ECHEC : le trace relu s'ecarte de ", roundi(drift * 100.0), " %")
	else:
		print("OK : trace conserve (ecart ", roundi(drift * 100.0), " %)")

func _count(lab: Node) -> int:
	var mask: PackedByteArray = lab._interest_mask
	var total := 0
	for cell in mask.size():
		if mask[cell] != 0:
			total += 1
	return total
