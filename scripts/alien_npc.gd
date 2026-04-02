extends Node3D
class_name AlienNPC
# FRONTIER — Alien NPC behaviour
# Aliens patrol around their home point, flee when the ship gets close.
# After being scanned (registered in GameState) they return home and idle.

enum Mode { IDLE, PATROL, FLEE }

const PATROL_RADIUS : float = 200.0
const PATROL_SPEED  : float = 24.0
const FLEE_SPEED    : float = 130.0
const FLEE_RANGE    : float = 380.0   # ship closer than this → FLEE
const IDLE_SPEED    : float = 8.0
const ORBIT_DRIFT   : float = 0.18    # radians/s orbital speed

var _home         : Vector3 = Vector3.ZERO
var _mode         : int     = Mode.PATROL
var _ship         : Node3D  = null
var _alien_id     : String  = ""
var _orbit_angle  : float   = 0.0
var _orbit_height : float   = 0.0
var _rot_speed    : Vector3 = Vector3.ZERO
var _flee_bias    : Vector3 = Vector3.ZERO   # randomised flee direction offset

func _ready() -> void:
	_home         = position
	_orbit_angle  = randf() * TAU
	_orbit_height = randf_range(-55.0, 55.0)
	_rot_speed    = Vector3(
		randf_range(-0.25, 0.25),
		randf_range(0.15, 0.65),
		randf_range(-0.18, 0.18)
	)
	_flee_bias = Vector3(
		randf_range(-0.4, 0.4),
		randf_range(-0.2, 0.2),
		randf_range(-0.4, 0.4)
	).normalized() * 0.35
	if has_meta("alien_data"):
		_alien_id = get_meta("alien_data").get("id", "")

func set_ship(ship: Node3D) -> void:
	## MUTATE_GLOBAL — called by space_world after the ship is spawned
	_ship = ship

func _process(delta: float) -> void:
	## DNA:update — drive NPC state machine, rotate mesh each frame
	rotation += _rot_speed * delta

	var registered: bool = _is_registered()
	if registered:
		_mode = Mode.IDLE
	elif is_instance_valid(_ship):
		var dist: float = global_position.distance_to(_ship.global_position)
		_mode = Mode.FLEE if dist < FLEE_RANGE else Mode.PATROL
	else:
		_mode = Mode.PATROL

	match _mode:
		Mode.IDLE:   _do_idle(delta)
		Mode.PATROL: _do_patrol(delta)
		Mode.FLEE:   _do_flee(delta)

# ── mode behaviours ────────────────────────────────────────────────────────

func _do_idle(delta: float) -> void:
	## DNA:movement — slow drift back toward spawn home
	var to_home: Vector3 = _home - global_position
	if to_home.length() > 8.0:
		global_position += to_home.normalized() * IDLE_SPEED * delta

func _do_patrol(delta: float) -> void:
	## DNA:movement — elliptical orbit around spawn home
	_orbit_angle += delta * ORBIT_DRIFT
	var target: Vector3 = _home + Vector3(
		cos(_orbit_angle) * PATROL_RADIUS,
		_orbit_height,
		sin(_orbit_angle) * PATROL_RADIUS
	)
	global_position = global_position.lerp(target, delta * 1.8)

func _do_flee(delta: float) -> void:
	## DNA:movement — bolt away from ship, bias to avoid collisions
	if not is_instance_valid(_ship): return
	var away: Vector3 = (global_position - _ship.global_position).normalized()
	var flee_dir: Vector3 = (away + _flee_bias).normalized()
	global_position += flee_dir * FLEE_SPEED * delta
	# Don't let aliens flee infinitely — pull back when far from home
	var home_dist: float = global_position.distance_to(_home)
	if home_dist > PATROL_RADIUS * 4.0:
		var back: Vector3 = (_home - global_position).normalized()
		global_position += back * FLEE_SPEED * 0.25 * delta

# ── helpers ────────────────────────────────────────────────────────────────

func _is_registered() -> bool:
	## QUERY_NODE — check GameState to see if this alien has been scanned
	if not has_node("/root/GameState"): return false
	var gs: Node = get_node("/root/GameState")
	return _alien_id in gs.registered_aliens
