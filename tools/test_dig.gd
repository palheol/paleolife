extends SceneTree

## Test de fumee du degagement : simule des gestes d'outil et verifie que la
## roche part, que le risque monte sur un geste rapide et qu'une fissure apparait.
## Usage : godot --path . --script res://tools/test_dig.gd

var _frames := 0
var _lab: Node

func _initialize() -> void:
	_lab = (load("res://scenes/lab.tscn") as PackedScene).instantiate()
	root.add_child(_lab)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false

	var slab := _lab.get_node("RockSlab") as RockSlab
	var camera := _lab.get_node("OrbitCamera") as Camera3D
	var dig := _lab.get_node("DigController") as DigController
	var centre := Vector2(root.size) * 0.5

	var ray := slab.raycast(camera.project_ray_origin(centre), camera.project_ray_normal(centre))
	print("rayon au centre -> touche=", ray.get("hit", false), " cellule=", ray.get("cell", "-"))

	var before := slab.cleared_ratio(PackedByteArray())
	print("couches sous le curseur avant : ", slab.get_layers_at(ray["cell"].x, ray["cell"].y)
		if ray.get("hit", false) else -1)

	# Geste lent au percuteur : la roche doit se degrossir sans risque notable.
	dig.select_tool(DigController.Tool.PERCUTEUR)
	for step in 12:
		dig._apply_at(centre + Vector2(float(step) * 4.0, 0.0))
	print("apres percuteur : couches=", slab.get_layers_at(ray["cell"].x, ray["cell"].y),
		" risque=", dig.risk)

	# Puis le pinceau, qui seul retire la derniere couche.
	dig.select_tool(DigController.Tool.PINCEAU)
	for step in 12:
		dig._apply_at(centre + Vector2(float(step) * 4.0, 0.0))
	print("apres pinceau  : couches=", slab.get_layers_at(ray["cell"].x, ray["cell"].y))

	var after := slab.cleared_ratio(PackedByteArray())
	print("degagement : ", snappedf(before * 100.0, 0.1), " % -> ", snappedf(after * 100.0, 0.1), " %")

	# Fissure : on force le risque au maximum puis on declenche.
	dig.risk = 1.0
	dig._add_crack()
	print("fissures apres declenchement : ", dig._crack_positions.size(),
		" valeur scientifique=", dig.science_value)

	# Recollage : on vise la fissure a l'ecran ; elle disparait, le malus reste.
	dig.select_tool(DigController.Tool.COLLE)
	var crack_screen := camera.unproject_position(dig._crack_positions[0]) \
		if dig._crack_positions.size() > 0 else centre
	dig._try_glue(crack_screen)
	print("apres colle : fissures=", dig._crack_positions.size(),
		" valeur scientifique=", dig.science_value)
	return true
