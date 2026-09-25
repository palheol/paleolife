extends Camera3D
class_name OrbitCamera

## Camera orbitale douce au-dessus de la plaque.
## Clic droit maintenu = pivoter, molette = zoomer.
## Le clic gauche reste volontairement libre : il servira aux outils du labo.

@export var min_pitch_degrees: float = 20.0
@export var max_pitch_degrees: float = 87.0
@export var orbit_sensitivity: float = 0.006
@export var zoom_step: float = 0.12
## Plus la valeur est basse, plus le mouvement est mou (ambiance cosy, pas de saccade).
@export var smoothing: float = 9.0

var _target: Vector3 = Vector3.ZERO
var _wanted_yaw: float = 0.6
var _wanted_pitch: float = deg_to_rad(62.0)
var _wanted_distance: float = 1.0
var _yaw: float = 0.6
var _pitch: float = deg_to_rad(62.0)
var _distance: float = 1.0
var _min_distance: float = 0.2
var _max_distance: float = 3.0
var _orbiting: bool = false

func _ready() -> void:
	current = true
	near = 0.01
	far = 100.0

## Recentre la camera sur un point, en adaptant les distances a la taille de l'objet.
func focus_on(point: Vector3, span: float) -> void:
	_target = point
	_min_distance = span * 0.35
	_max_distance = span * 4.0
	_wanted_distance = span * 1.15
	_distance = _wanted_distance
	_yaw = _wanted_yaw
	_pitch = _wanted_pitch
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_wanted_distance = clampf(_wanted_distance * (1.0 - zoom_step), _min_distance, _max_distance)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_wanted_distance = clampf(_wanted_distance * (1.0 + zoom_step), _min_distance, _max_distance)
		return

	var motion := event as InputEventMouseMotion
	if motion != null and _orbiting:
		_wanted_yaw -= motion.relative.x * orbit_sensitivity
		_wanted_pitch = clampf(
			_wanted_pitch + motion.relative.y * orbit_sensitivity,
			deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))

func _process(delta: float) -> void:
	var weight := clampf(delta * smoothing, 0.0, 1.0)
	_yaw = lerpf(_yaw, _wanted_yaw, weight)
	_pitch = lerpf(_pitch, _wanted_pitch, weight)
	_distance = lerpf(_distance, _wanted_distance, weight)
	_apply()

func _apply() -> void:
	var direction := Vector3(
		cos(_pitch) * sin(_yaw),
		sin(_pitch),
		cos(_pitch) * cos(_yaw))
	global_position = _target + direction * _distance
	look_at(_target, Vector3.UP)
