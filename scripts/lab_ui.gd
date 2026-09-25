extends CanvasLayer
class_name LabUI

## Interface du labo : choix de l'outil, jauge de risque et compteurs.
## Construite par code pour garder la scene lisible et facile a faire evoluer.

signal tool_requested(tool: DigController.Tool)

const SAFE_COLOR := Color(0.42, 0.60, 0.34)
const WARNING_COLOR := Color(0.85, 0.60, 0.24)
const DANGER_COLOR := Color(0.76, 0.33, 0.25)

var _title: Label
var _risk_fill: ColorRect
var _risk_bar: PanelContainer
var _stats: Label
var _hint: Label
var _tool_buttons: Dictionary = {}

func _ready() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 18)
	root.add_theme_constant_override("margin_top", 14)
	root.add_theme_constant_override("margin_right", 18)
	root.add_theme_constant_override("margin_bottom", 14)
	add_child(root)

	var column := VBoxContainer.new()
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

	select_tool(DigController.Tool.PERCUTEUR)
	set_risk(0.0)

func _build_toolbar() -> Control:
	var row := HBoxContainer.new()
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
	column.add_theme_constant_override("separation", 3)

	var caption := Label.new()
	caption.text = "Risque de fissure"
	caption.add_theme_color_override("font_color", Color(0.72, 0.68, 0.60))
	column.add_child(caption)

	_risk_bar = PanelContainer.new()
	_risk_bar.custom_minimum_size = Vector2(280, 14)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.16, 0.14, 0.12)
	background.set_corner_radius_all(4)
	_risk_bar.add_theme_stylebox_override("panel", background)

	var holder := Control.new()
	holder.clip_contents = true
	_risk_bar.add_child(holder)

	_risk_fill = ColorRect.new()
	_risk_fill.color = SAFE_COLOR
	# Ancres en haut a gauche : la largeur est pilotee a la main par set_risk().
	_risk_fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	holder.add_child(_risk_fill)

	column.add_child(_risk_bar)
	return column

func set_title(text: String) -> void:
	if _title != null:
		_title.text = text

func select_tool(tool: DigController.Tool) -> void:
	for key in _tool_buttons:
		var button := _tool_buttons[key] as Button
		button.button_pressed = key == tool

func set_risk(ratio: float) -> void:
	if _risk_fill == null:
		return
	var width := _risk_bar.custom_minimum_size.x * clampf(ratio, 0.0, 1.0)
	_risk_fill.size = Vector2(width, _risk_bar.custom_minimum_size.y)
	_risk_fill.color = SAFE_COLOR
	if ratio > 0.75:
		_risk_fill.color = DANGER_COLOR
	elif ratio > 0.45:
		_risk_fill.color = WARNING_COLOR

func set_stats(cleared: float, science_value: float, crack_count: int) -> void:
	if _stats == null:
		return
	_stats.text = "Degagement : %d %%   ·   Valeur scientifique : %d %%   ·   Fissures : %d" % [
		roundi(cleared * 100.0), roundi(science_value), crack_count]
