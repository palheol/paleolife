extends SceneTree

## Verifie que le labo n'altere pas les specimens. Pour chaque piece de la
## collection, on compare le modele tel qu'il est sur le disque a ce qui est
## reellement pose sur l'etabli, et on controle que la transformation appliquee
## reste une similitude : rotation et mise a l'echelle uniforme, rien d'autre.
##
## Un cisaillement, une echelle non uniforme ou un nombre de sommets different
## signifierait que la geometrie a ete deformee — inacceptable sur une piece
## scientifique.
##
## Usage : godot --path . --script res://tools/test_specimen_integrity.gd

var _frames := 0
var _lab: Node
var _queue: Array[FossilData] = []
var _index := -1
var _failures := 0

func _initialize() -> void:
	_lab = (load("res://scenes/lab.tscn") as PackedScene).instantiate()
	root.add_child(_lab)
	_queue = FossilLibrary.all_fossils()

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	_index += 1
	if _index >= _queue.size():
		print("")
		print("resultat : ", _failures, " anomalie(s) sur ", _queue.size(), " piece(s)")
		return true

	var fossil := _queue[_index]
	_lab.load_fossil(fossil)
	_check(fossil)
	return false

func _check(fossil: FossilData) -> void:
	var expected := _source_vertex_count(fossil.model_path)
	var placed := 0
	var worst_shear := 0.0
	var worst_anisotropy := 0.0
	var mirrored := false

	var anchor := _lab.get_node("FossilRoot") as Node3D
	for instance in _mesh_instances(anchor):
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			if not arrays.is_empty():
				placed += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

		var basis := (anchor.global_transform.affine_inverse() * instance.global_transform).basis
		var x := basis.x.length()
		var y := basis.y.length()
		var z := basis.z.length()
		# Colonnes de longueurs egales : l'echelle est uniforme.
		worst_anisotropy = maxf(worst_anisotropy,
			(maxf(x, maxf(y, z)) / maxf(0.000001, minf(x, minf(y, z)))) - 1.0)
		# Colonnes perpendiculaires : aucune deformation en cisaillement.
		worst_shear = maxf(worst_shear, absf(basis.x.normalized().dot(basis.y.normalized())))
		worst_shear = maxf(worst_shear, absf(basis.y.normalized().dot(basis.z.normalized())))
		worst_shear = maxf(worst_shear, absf(basis.x.normalized().dot(basis.z.normalized())))
		if basis.determinant() < 0.0:
			mirrored = true

	var problems: Array[String] = []
	if expected >= 0 and placed != expected:
		problems.append("sommets %d au lieu de %d" % [placed, expected])
	if worst_anisotropy > 0.001:
		problems.append("echelle non uniforme (%.4f)" % worst_anisotropy)
	if worst_shear > 0.001:
		problems.append("cisaillement (%.4f)" % worst_shear)
	if mirrored:
		problems.append("modele inverse")

	if problems.is_empty():
		print("  OK   ", fossil.id, " — ", placed, " sommets, ",
			"plaque redressee" if fossil.on_plate else "volume laisse tel quel")
	else:
		_failures += 1
		printerr("  ECHEC ", fossil.id, " : ", ", ".join(problems))

## Nombre de sommets du fichier d'origine, avant toute intervention du labo.
## Les objets parasites que le labo ecarte volontairement (boites d'aide laissees
## par Sketchfab) sont retranches ici aussi, faute de quoi leur absence sur
## l'etabli passerait pour une perte de geometrie.
func _source_vertex_count(path: String) -> int:
	if not ResourceLoader.exists(path):
		return -1
	var resource := ResourceLoader.load(path)
	var total := 0
	if resource is Mesh:
		total = _count_in_mesh(resource)
	elif resource is PackedScene:
		var copy := (resource as PackedScene).instantiate()
		for instance in _mesh_instances(copy):
			if not _is_excluded(instance):
				total += _count_in_mesh(instance.mesh)
		copy.queue_free()
	return total

func _is_excluded(node: Node) -> bool:
	var fragments: PackedStringArray = _lab.excluded_node_names
	var current := node
	while current != null:
		for fragment in fragments:
			if not fragment.is_empty() and String(current.name).contains(fragment):
				return true
		current = current.get_parent()
	return false

func _count_in_mesh(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		if not arrays.is_empty():
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return total

func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var instance := root as MeshInstance3D
	if instance != null and instance.mesh != null and instance.visible:
		found.append(instance)
	for child in root.get_children():
		found.append_array(_mesh_instances(child))
	return found
