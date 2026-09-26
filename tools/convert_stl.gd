extends SceneTree

## Convertit un STL binaire en OBJ, en allegeant le maillage au passage.
## Godot n'importe pas le format STL, et les scans bruts depassent souvent le
## million de triangles : inexploitable tel quel dans un jeu.
##
## Methode : regroupement de sommets. L'espace est decoupe en une grille, tous
## les sommets d'une meme case fusionnent en leur centre de gravite, et les
## triangles devenus plats sont ecartes. C'est simple et robuste ; une
## decimation par contraction d'aretes donnerait un meilleur resultat a nombre
## de triangles egal, mais demande un vrai outil de maillage.
##
## Usage :
##   godot --path . --script res://tools/convert_stl.gd -- <entree.stl> <sortie.obj> [resolution]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Usage : <entree.stl> <sortie.obj> [resolution]")
		quit(1)
		return
	var resolution := 220
	if args.size() > 2:
		resolution = maxi(8, int(args[2]))
	_convert(args[0], args[1], resolution)
	quit()

func _convert(source: String, destination: String, resolution: int) -> void:
	var started := Time.get_ticks_msec()
	var bytes := FileAccess.get_file_as_bytes(source)
	if bytes.is_empty():
		printerr("Fichier illisible : ", source)
		return
	if bytes.size() < 84:
		printerr("Fichier trop court pour un STL binaire.")
		return

	var triangles := bytes.decode_u32(80)
	var expected := 84 + triangles * 50
	if bytes.size() < expected:
		printerr("Taille incoherente : ", bytes.size(), " octets pour ", triangles, " triangles.")
		return
	print("STL : ", triangles, " triangles")

	# Lecture des sommets (on ignore la normale stockee, recalculee plus tard).
	var coordinates := PackedFloat32Array()
	coordinates.resize(triangles * 9)
	var lowest := Vector3(INF, INF, INF)
	var highest := Vector3(-INF, -INF, -INF)
	var offset := 84
	var write := 0
	for triangle in triangles:
		offset += 12 # normale
		for corner in 3:
			var x := bytes.decode_float(offset)
			var y := bytes.decode_float(offset + 4)
			var z := bytes.decode_float(offset + 8)
			offset += 12
			coordinates[write] = x
			coordinates[write + 1] = y
			coordinates[write + 2] = z
			write += 3
			lowest = Vector3(minf(lowest.x, x), minf(lowest.y, y), minf(lowest.z, z))
			highest = Vector3(maxf(highest.x, x), maxf(highest.y, y), maxf(highest.z, z))
		offset += 2 # attribut

	var extent := highest - lowest
	var cell := maxf(extent.x, maxf(extent.y, extent.z)) / float(resolution)
	if cell <= 0.0:
		printerr("Emprise nulle.")
		return
	print("emprise=", extent, " taille de case=", cell)

	# Regroupement : une case de la grille devient un sommet unique.
	var cluster_of: Dictionary = {}
	var sums := PackedFloat32Array()
	var counts := PackedInt32Array()
	var indices := PackedInt32Array()
	indices.resize(triangles * 3)

	for vertex in triangles * 3:
		var base := vertex * 3
		var gx := int(floor((coordinates[base] - lowest.x) / cell))
		var gy := int(floor((coordinates[base + 1] - lowest.y) / cell))
		var gz := int(floor((coordinates[base + 2] - lowest.z) / cell))
		var key := gx + gy * 1024 + gz * 1048576
		var cluster: int = cluster_of.get(key, -1)
		if cluster < 0:
			cluster = counts.size()
			cluster_of[key] = cluster
			counts.append(0)
			sums.append(0.0)
			sums.append(0.0)
			sums.append(0.0)
		var target := cluster * 3
		sums[target] += coordinates[base]
		sums[target + 1] += coordinates[base + 1]
		sums[target + 2] += coordinates[base + 2]
		counts[cluster] += 1
		indices[vertex] = cluster

	var writer := FileAccess.open(destination, FileAccess.WRITE)
	if writer == null:
		printerr("Ecriture impossible : ", destination)
		return
	writer.store_line("# Converti depuis " + source.get_file() + " par tools/convert_stl.gd")
	writer.store_line("o " + source.get_file().get_basename())

	for cluster in counts.size():
		var base := cluster * 3
		var weight := float(maxi(1, counts[cluster]))
		writer.store_line("v %f %f %f" % [
			sums[base] / weight, sums[base + 1] / weight, sums[base + 2] / weight])

	var kept := 0
	for triangle in triangles:
		var a := indices[triangle * 3]
		var b := indices[triangle * 3 + 1]
		var c := indices[triangle * 3 + 2]
		# Triangle aplati par la fusion : il ne decrit plus de surface.
		if a == b or b == c or a == c:
			continue
		writer.store_line("f %d %d %d" % [a + 1, b + 1, c + 1])
		kept += 1
	writer.close()

	print("OBJ ecrit : ", counts.size(), " sommets, ", kept, " triangles (",
		Time.get_ticks_msec() - started, " ms)")
