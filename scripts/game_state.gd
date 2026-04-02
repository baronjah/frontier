extends Node
## GameState — autoload: save/load + game clock + scheduler
## TREE_STRUCTURE — singleton added to project.godot as GameState

const SAVE_PATH := "user://frontier_save.json"

# ── persistent data ────────────────────────────────────────────────────────
var credits:            int            = 1000
var woolongs:           int            = 0
var cargo:              Dictionary     = {}
var registered_aliens:  Array[String]  = []
var pending_aliens:     Array          = []   # [{id: String, woolongs: int}] — scanned, not yet collected
var upgrades:           Dictionary     = {}   # {"engine_mk2": true, "cargo_1": true, ...}
var ship_position:      Vector3        = Vector3.ZERO
var ship_basis:         Basis          = Basis.IDENTITY

# ── game clock ─────────────────────────────────────────────────────────────
## 1 real-second = 60 game-minutes  (1 game-day ≈ 24 real-seconds)
const GAME_MINUTES_PER_SECOND := 60.0

var game_minutes:  float = 480.0   # start at 08:00
var game_day:      int   = 1
var _clock_paused: bool  = false

signal dawn                     # fires at  06:00 each day
signal dusk                     # fires at  20:00 each day
signal day_changed(day: int)

# ── scheduled events ───────────────────────────────────────────────────────
## Entry: { "day": int, "minute": float, "event": String, "done": bool }
var schedule: Array = []

signal event_triggered(event_name: String)

# ── internal ────────────────────────────────────────────────────────────────
var _prev_hour: float = -1.0

# ──────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	load_game()

func _process(delta: float) -> void:
	if _clock_paused: return
	_tick_clock(delta)
	_check_schedule()

# ── clock ──────────────────────────────────────────────────────────────────
func _tick_clock(delta: float) -> void:
	## MUTATE_GLOBAL — advances game_minutes and game_day
	game_minutes += delta * GAME_MINUTES_PER_SECOND
	if game_minutes >= 1440.0:   # 24 * 60
		game_minutes -= 1440.0
		game_day += 1
		day_changed.emit(game_day)

	var hour := game_minutes / 60.0
	if _prev_hour < 6.0 and hour >= 6.0:
		dawn.emit()
	if _prev_hour < 20.0 and hour >= 20.0:
		dusk.emit()
	_prev_hour = hour

func get_time_string() -> String:
	## RETURN_VALUE — "HH:MM Day N"
	var h := int(game_minutes / 60.0) % 24
	var m := int(game_minutes) % 60
	return "%02d:%02d  Day %d" % [h, m, game_day]

func pause_clock() -> void:
	_clock_paused = true

func resume_clock() -> void:
	_clock_paused = false

# ── scheduler ─────────────────────────────────────────────────────────────
func schedule_event(day: int, minute: float, event_name: String) -> void:
	## MUTATE_GLOBAL — adds a timed event
	schedule.append({"day": day, "minute": minute, "event": event_name, "done": false})

func _check_schedule() -> void:
	## MUTATE_GLOBAL — fires due events
	for entry in schedule:
		if entry["done"]: continue
		if game_day >= entry["day"] and game_minutes >= entry["minute"]:
			entry["done"] = true
			event_triggered.emit(entry["event"])

# ── save / load ────────────────────────────────────────────────────────────
func save_game() -> void:
	## MUTATE_GLOBAL — writes persistent state to disk
	var data := {
		"credits":           credits,
		"woolongs":          woolongs,
		"cargo":             cargo,
		"registered_aliens": registered_aliens,
		"pending_aliens":    pending_aliens,
		"upgrades":          upgrades,
		"ship_position":     {"x": ship_position.x, "y": ship_position.y, "z": ship_position.z},
		"ship_basis":        _basis_to_array(ship_basis),
		"game_minutes":      game_minutes,
		"game_day":          game_day,
		"schedule":          schedule,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()

func load_game() -> void:
	## MUTATE_GLOBAL — restores persistent state from disk
	if not FileAccess.file_exists(SAVE_PATH): return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f: return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not parsed is Dictionary: return
	var d: Dictionary = parsed
	credits            = d.get("credits",           1000)
	woolongs           = d.get("woolongs",           0)
	cargo              = d.get("cargo",              {})
	registered_aliens  = Array(d.get("registered_aliens", []), TYPE_STRING, "", null)
	pending_aliens     = d.get("pending_aliens", [])
	upgrades           = d.get("upgrades", {})
	var sp: Dictionary = d.get("ship_position", {})
	ship_position      = Vector3(sp.get("x",0.0), sp.get("y",0.0), sp.get("z",0.0))
	ship_basis         = _array_to_basis(d.get("ship_basis", []))
	game_minutes       = d.get("game_minutes", 480.0)
	game_day           = d.get("game_day",     1)
	schedule           = d.get("schedule",     [])

func snapshot_ship(ship: Node3D) -> void:
	## QUERY_NODE — capture ship position/basis before going on-foot
	ship_position = ship.global_position
	ship_basis    = ship.global_basis

# ── helpers ────────────────────────────────────────────────────────────────
func _basis_to_array(b: Basis) -> Array:
	return [b.x.x,b.x.y,b.x.z, b.y.x,b.y.y,b.y.z, b.z.x,b.z.y,b.z.z]

func _array_to_basis(a: Array) -> Basis:
	if a.size() < 9: return Basis.IDENTITY
	return Basis(
		Vector3(a[0],a[1],a[2]),
		Vector3(a[3],a[4],a[5]),
		Vector3(a[6],a[7],a[8])
	)
