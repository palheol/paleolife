extends CanvasLayer
class_name LabUI

## Interface du labo : choix de l'outil, jauge de risque et compteurs.
## Construite par code pour garder la scene lisible et facile a faire evoluer.

signal tool_requested(tool: DigController.Tool)
signal fossil_requested(fossil: FossilData)
signal zone_overlay_toggled(visible_zone: bool)
signal zone_edit_toggled(active: bool)
signal zone_erase_toggled(erasing: bool)
signal zone_save_requested()

const SAFE_COLOR := Color(0.42, 0.60, 0.34)
const WARNING_COLOR := Color(0.85, 0.60, 0.24)
const DANGER_COLOR := Color(0.76, 0.33, 0.25)

var _title: Label
var _risk_fill: ColorRect
var _risk_bar: PanelContainer
var _risk_track: Control
var _risk_ratio: float = 0.0
var _stats: Label
var _hint: Label
var _tool_buttons: Dictionary = {}
var _collection_button: Button
var _collection_panel: PanelContainer
var _collection_list: VBoxContainer
var _admin_button: Button
var _admin_panel: PanelContainer

func _ready() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Le conteneur couvre tout l'ecran : sans cela il capterait le survol de la
	# souris partout, ce qui masquerait le curseur 3D de l'outil et priverait la
	# scene des clics. Seuls les boutons restent sensibles.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_left", 18)
	root.add_theme_constant_override("margin_top", 14)
	root.add_theme_constant_override("margin_right", 18)
	root.add_theme_constant_override("margin_bottom", 14)
	add_child(root)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	root.add_child(column)

	_title = Label.new()
	_title.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82))
	column.add_child(_title)

	column.add_child(_build_toolbar())
	column.add_child(_build_risk_gauge())

	_stats = Label.new()
	_stats.add_theme_color_override("font_color", Color(0.95, 0.91, 0.82))
	column.add_child(_stats)

	_hint = Label.new()
	_hint.text = "Clic gauche : outil actif · Clic droit glisse : pivoter · Molette : zoomer"
	_hint.add_theme_color_override("font_color", Color(0.72, 0.68, 0.60))
	column.add_child(_hint)

	column.add_child(_build_collection_panel())
	column.add_child(_build_admin_panel())

	select_tool(DigController.Tool.PERCUTEUR)
	set_risk(0.0)

func _build_toolbar() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	_add_tool_button(row, DigController.Tool.PERCUTEUR, "Micro-percuteur",
		"Degrossit la gangue. Geste ample et rapide = risque de fissure.")
	_add_tool_button(row, DigController.Tool.PINCEAU, "Pinceau",
		"Derniere couche et finition. Aucun risque.")
	_add_tool_button(row, DigController.Tool.COLLE, "Colle",
		"Recolle une fissure. La valeur scientifique perdue ne revient pas.")
	return row

func _add_tool_button(row: HBoxContainer, tool: DigController.Tool, label: String,
		tooltip: String) -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: tool_requested.emit(tool))
	row.add_child(button)
	_tool_buttons[tool] = button

func _build_risk_gauge() -> Control:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)

	var caption := Label.new()
	caption.text = "Risque de fissure"
	caption.add_theme_color_override("font_color", Color(0.72, 0.68, 0.60))
	column.add_child(caption)

	_risk_bar = PanelContainer.new()
	_risk_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_risk_bar.custom_minimum_size = Vector2(280, 14)
	# Sans cela le conteneur s'etire sur toute la largeur de la fenetre, et le
	# remplissage n'atteint jamais le bout de la barre.
	_risk_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.16, 0.14, 0.12)
	background.set_corner_radius_all(4)
	_risk_bar.add_theme_stylebox_override("panel", background)

	_risk_track = Control.new()
	_risk_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_risk_track.clip_contents = true
	_risk_track.resized.connect(_update_risk_fill)
	_risk_bar.add_child(_risk_track)

	_risk_fill = ColorRect.new()
	_risk_fill.color = SAFE_COLOR
	# Ancres en haut a gauche : la largeur est pilotee a la main par set_risk().
	_risk_fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_risk_track.add_child(_risk_fill)

	column.add_child(_risk_bar)
	return column

## Collection : un tiroir que l'on ouvre pour choisir la piece suivante. On y
## lit la provenance du bloc, jamais l'espece — c'est l'etude qui la revele.
func _build_collection_panel() -> Control:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)

	_collection_button = Button.new()
	_collection_button.text = "▸ Collection"
	_collection_button.focus_mode = Control.FOCUS_NONE
	_collection_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_collection_button.pressed.connect(_toggle_collection)
	column.add_child(_collection_button)

	_collection_panel = PanelContainer.new()
	_collection_panel.visible = false
	_collection_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.13, 0.11, 0.09, 0.92)
	background.set_corner_radius_all(6)
	background.set_content_margin_all(10)
	_collection_panel.add_theme_stylebox_override("panel", background)

	_collection_list = VBoxContainer.new()
	_collection_list.add_theme_constant_override("separation", 4)
	_collection_panel.add_child(_collection_list)
	column.add_child(_collection_panel)
	return column

func _toggle_collection() -> void:
	_collection_panel.visible = not _collection_panel.visible
	_collection_button.text = ("▾ Collection" if _collection_panel.visible
		else "▸ Collection")

func set_collection(fossils: Array[FossilData]) -> void:
	if _collection_list == null:
		return
	for child in _collection_list.get_children():
		child.queue_free()
	if fossils.is_empty():
		var empty := Label.new()
		empty.text = "Aucun bloc en reserve."
		_collection_list.add_child(empty)
		return
	var number := 0
	for entry in fossils:
		number += 1
		var button := Button.new()
		button.text = "Bloc n°%d — %s" % [number, _origin_of(entry)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void:
			_toggle_collection()
			fossil_requested.emit(entry))
		_collection_list.add_child(button)

func _origin_of(entry: FossilData) -> String:
	var site := FossilLibrary.site_for(entry)
	if site == null:
		return "provenance inconnue"
	return "%s, %s" % [site.site_name, site.region]

## Volet de reglage, destine a la mise au point et non au joueur : il montre la
## zone que la detection retient comme "a degager", pour verifier qu'elle suit
## bien la piece, et laisse ajuster le seuil en direct.
func _build_admin_panel() -> Control:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)

	_admin_button = Button.new()
	_admin_button.text = "▸ Réglage"
	_admin_button.focus_mode = Control.FOCUS_NONE
	_admin_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_admin_button.pressed.connect(func() -> void:
		_admin_panel.visible = not _admin_panel.visible
		_admin_button.text = "▾ Réglage" if _admin_panel.visible else "▸ Réglage")
	column.add_child(_admin_button)

	_admin_panel = PanelContainer.new()
	_admin_panel.visible = false
	_admin_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.13, 0.11, 0.09, 0.92)
	background.set_corner_radius_all(6)
	background.set_content_margin_all(10)
	_admin_panel.add_theme_stylebox_override("panel", background)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)

	var show := CheckButton.new()
	show.text = "Afficher la zone à dégager"
	show.focus_mode = Control.FOCUS_NONE
	show.toggled.connect(func(pressed: bool) -> void: zone_overlay_toggled.emit(pressed))
	inner.add_child(show)

	var edit := CheckButton.new()
	edit.text = "Tracer la zone sur la pièce propre"
	edit.focus_mode = Control.FOCUS_NONE
	edit.toggled.connect(func(pressed: bool) -> void: zone_edit_toggled.emit(pressed))
	inner.add_child(edit)

	var erase := CheckButton.new()
	erase.text = "Gomme"
	erase.focus_mode = Control.FOCUS_NONE
	erase.toggled.connect(func(pressed: bool) -> void: zone_erase_toggled.emit(pressed))
	inner.add_child(erase)

	var help := Label.new()
	help.text = "Clic gauche : peindre · le tracé s'applique ensuite aux joueurs"
	help.add_theme_color_override("font_color", Color(0.72, 0.68, 0.60))
	inner.add_child(help)

	var save := Button.new()
	save.text = "Enregistrer la zone"
	save.focus_mode = Control.FOCUS_NONE
	save.pressed.connect(func() -> void: zone_save_requested.emit())
	inner.add_child(save)

	_admin_panel.add_child(inner)
	column.add_child(_admin_panel)
	return column

func set_title(text: String) -> void:
	if _title != null:
		_title.text = text

func select_tool(tool: DigController.Tool) -> void:
	for key in _tool_buttons:
		var button := _tool_buttons[key] as Button
		button.button_pressed = key == tool

func set_risk(ratio: float) -> void:
	_risk_ratio = clampf(ratio, 0.0, 1.0)
	_update_risk_fill()

## La largeur est recalculee a partir de la taille reelle de la barre, pas de sa
## taille minimale, et rejouee a chaque redimensionnement de la fenetre.
func _update_risk_fill() -> void:
	if _risk_fill == null or _risk_track == null:
		return
	var track := _risk_track.size
	if track.x <= 0.0:
		track = _risk_bar.custom_minimum_size
	_risk_fill.size = Vector2(track.x * _risk_ratio, track.y)
	_risk_fill.color = SAFE_COLOR
	if _risk_ratio > 0.75:
		_risk_fill.color = DANGER_COLOR
	elif _risk_ratio > 0.45:
		_risk_fill.color = WARNING_COLOR

func set_stats(cleared: float, science_value: float, crack_count: int) -> void:
	if _stats == null:
		return
	_stats.text = "Degagement : %d %%   ·   Valeur scientifique : %d %%   ·   Fissures : %d" % [
		roundi(cleared * 100.0), roundi(science_value), crack_count]
