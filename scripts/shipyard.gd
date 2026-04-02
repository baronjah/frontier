extends Node3D
## Shipyard — spend woolongs on permanent ship upgrades.
## TREE_STRUCTURE — builds everything in code, self-contained scene.
##
## Upgrades available:
##   engine_mk2    — max speed ×1.5, boost duration ×1.4          5 000 ₩
##   cargo_1       — cargo capacity +10 (20→30)                   3 000 ₩
##   scanner_mk2   — scan range 500m → 1 200m                     4 000 ₩
##   cargo_2       — cargo capacity +10 more (30→40)              6 000 ₩
##   engine_mk3    — max speed ×2.0 total, boost recharge ×0.7    8 000 ₩
##
## G near launch pad → save + change_scene_to main.tscn

const UPGRADES: Array[Dictionary] = [
	{"id":"engine_mk2",  "name":"ENGINE Mk.II",       "desc":"Speed ×1.5 · Boost +40%",     "cost":5000},
	{"id":"cargo_1",     "name":"CARGO EXPANSION I",  "desc":"Cargo cap +10 (→30)",          "cost":3000},
	{"id":"scanner_mk2", "name":"SCANNER Mk.II",       "desc":"Scan range 500→1200m",         "cost":4000},
	{"id":"cargo_2",     "name":"CARGO EXPANSION II",  "desc":"Cargo cap +10 (→40)",          "cost":6000},
	{"id":"engine_mk3",  "name":"ENGINE Mk.III",       "desc":"Speed ×2.0 · Recharge -30%",  "cost":8000},
]

const STEEL    := Color(0.22, 0.24, 0.30)
const ACCENT   := Color(0.9,  0.55, 0.1)
const CYAN     := Color(0.10, 0.80, 0.95)
const DARK     := Color(0.05, 0.04, 0.08)

var _player:       Node3D  = null
var _well:         Node3D  = null
var _hud:          Label   = null
var _near_upgrade: int     = -1
var _near_launch:  bool    = false
var _woolongs:     int     = 0
var _upgrades:     Dictionary = {}
var _upgrade_positions: Array[Vector3] = []

func _ready() -> void:
	_load_from_game_state()
	_build_environment()
	_build_room()
	_build_upgrade_bays()
	_build_launch_pad()
	_build_gravity()
	_build_hud()
	_spawn_player()

# ── GameState ───────────────────────────────────────────────────────────────

func _load_from_game_state() -> void:
	if not has_node("/root/GameState"): return
	var gs    := get_node("/root/GameState")
	_woolongs  = gs.woolongs
	_upgrades  = gs.upgrades.duplicate()

func _save_to_game_state() -> void:
	if not has_node("/root/GameState"): return
	var gs    := get_node("/root/GameState")
	gs.woolongs  = _woolongs
	gs.upgrades  = _upgrades.duplicate()
	gs.save_game()

# ── environment ─────────────────────────────────────────────────────────────

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = Color(0.004, 0.003, 0.008, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.35, 0.30, 0.22)
	env.ambient_light_energy = 0.6
	env.glow_enabled   = true
	env.glow_intensity = 0.9
	env.glow_bloom     = 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_energy     = 2.0
	sun.light_color      = Color(1.0, 0.92, 0.78)
	sun.shadow_enabled   = true
	sun.rotation_degrees = Vector3(-30, 20, 0)
	add_child(sun)

# ── room ────────────────────────────────────────────────────────────────────

func _build_room() -> void:
	var fm := _mat(Color(0.12, 0.10, 0.08), 0.9, 0.1)   # floor
	var wm := _mat(STEEL, 0.8, 0.3)                       # walls
	var cm := _mat(DARK,  0.9, 0.0)                       # ceiling

	# Floor + ceiling
	_slab(Vector3(28, 0.3, 22), Vector3(0, -0.15, 0), fm)
	_slab(Vector3(28, 0.3, 22), Vector3(0,  7.15, 0), cm)
	# Walls
	_wall(Vector3(0.3, 7, 22), Vector3(-14, 3.5, 0), wm)
	_wall(Vector3(0.3, 7, 22), Vector3( 14, 3.5, 0), wm)
	_wall(Vector3(28, 7, 0.3), Vector3(0, 3.5, -11), wm)  # back wall
	# Entry — open front (z=+11 side, no wall so player spawns here)

	# Overhead industrial lights
	for xp: float in [-8.0, 0.0, 8.0]:
		var l := SpotLight3D.new()
		l.position        = Vector3(xp, 6.8, -2.0)
		l.rotation_degrees = Vector3(-90, 0, 0)
		l.light_color     = Color(1.0, 0.92, 0.78)
		l.light_energy    = 3.5
		l.spot_range      = 12.0
		l.spot_angle      = 40.0
		add_child(l)

	# Accent strip along back wall
	var strip_m := _emit_mat(ACCENT, ACCENT, 1.4)
	_wall(Vector3(26, 0.08, 0.06), Vector3(0, 0.18, -10.8), strip_m)

	# "SHIPYARD" sign
	var sign := Label3D.new()
	sign.text       = "SHIPYARD"
	sign.pixel_size = 0.022
	sign.position   = Vector3(0, 6.0, -10.5)
	sign.rotation_degrees = Vector3(0, 180, 0)
	sign.modulate   = ACCENT
	add_child(sign)

	# Sub-sign
	var sub := Label3D.new()
	sub.text       = "UPGRADE YOUR VESSEL · PAY IN WOOLONGS"
	sub.pixel_size = 0.010
	sub.position   = Vector3(0, 5.3, -10.5)
	sub.rotation_degrees = Vector3(0, 180, 0)
	sub.modulate   = CYAN
	add_child(sub)

# ── upgrade bays ────────────────────────────────────────────────────────────

func _build_upgrade_bays() -> void:
	## TREE_STRUCTURE — one bay per upgrade, evenly spaced along back wall
	_upgrade_positions.clear()
	var count  := UPGRADES.size()
	var span   := 22.0
	var step   := span / float(count)
	var start_x := -span * 0.5 + step * 0.5

	for i in count:
		var ud   := UPGRADES[i]
		var xpos := start_x + i * step
		var bpos := Vector3(xpos, 0.0, -8.5)
		_upgrade_positions.append(bpos)
		_build_upgrade_bay(bpos, ud, i)

func _build_upgrade_bay(pos: Vector3, ud: Dictionary, idx: int) -> void:
	var owned   := _upgrades.get(ud["id"], false)
	var col     := ACCENT if not owned else Color(0.2, 0.7, 0.25)
	var em      := _emit_mat(col, col, owned ? 0.6 : 1.8)
	var dm      := _mat(STEEL.darkened(0.15), 0.75, 0.4)

	# Pedestal
	_slab(Vector3(2.4, 1.0, 1.6), pos + Vector3(0, 0.5, 0), dm)
	# Top glow strip
	_wall(Vector3(2.2, 0.06, 1.4), pos + Vector3(0, 1.04, 0), em)

	# Small ship/part model on pedestal — just a suggestive shape
	var part_m := _emit_mat(col.darkened(0.2), col, 0.9)
	var part   := MeshInstance3D.new()
	var pm     := BoxMesh.new()
	pm.size    = Vector3(0.7, 0.4, 0.5)
	pm.material = part_m
	part.mesh  = pm
	part.position = pos + Vector3(0, 1.35, 0)
	add_child(part)

	# Name label
	var name_lbl := Label3D.new()
	name_lbl.text       = ud["name"]
	name_lbl.pixel_size = 0.011
	name_lbl.position   = pos + Vector3(0, 2.1, 0)
	name_lbl.billboard  = BaseMaterial3D.BILLBOARD_ENABLED
	name_lbl.modulate   = col
	add_child(name_lbl)

	# Desc + cost label
	var cost_str := "OWNED" if owned else "%d ₩" % ud["cost"]
	var desc_lbl := Label3D.new()
	desc_lbl.text       = "%s\n%s" % [ud["desc"], cost_str]
	desc_lbl.pixel_size = 0.009
	desc_lbl.position   = pos + Vector3(0, 1.75, 0)
	desc_lbl.billboard  = BaseMaterial3D.BILLBOARD_ENABLED
	desc_lbl.modulate   = Color(0.85, 0.85, 0.85)
	add_child(desc_lbl)

	# Bay light
	var bl := OmniLight3D.new()
	bl.position    = pos + Vector3(0, 3.5, 0)
	bl.light_color = col
	bl.light_energy = owned ? 0.8 : 1.8
	bl.omni_range  = 5.0
	add_child(bl)

# ── launch pad ──────────────────────────────────────────────────────────────

func _build_launch_pad() -> void:
	var pad_m := _emit_mat(Color(0.3, 0.6, 1.0), Color(0.2, 0.5, 1.0), 0.7)
	_slab(Vector3(4, 0.05, 4), Vector3(0, 0.025, 9), pad_m)

	var sign := Label3D.new()
	sign.text       = "[ G ]  LAUNCH\nRETURN TO SHIP"
	sign.pixel_size = 0.015
	sign.position   = Vector3(0, 3.5, 10.5)
	sign.rotation_degrees = Vector3(0, 180, 0)
	sign.modulate   = CYAN
	add_child(sign)

	var ll := OmniLight3D.new()
	ll.position    = Vector3(0, 4.0, 9)
	ll.light_color = Color(0.3, 0.6, 1.0)
	ll.light_energy = 2.5
	ll.omni_range  = 8.0
	add_child(ll)

# ── gravity ─────────────────────────────────────────────────────────────────

func _build_gravity() -> void:
	var well := Node3D.new()
	well.set_script(load("res://scripts/gravity_well.gd"))
	well.position = Vector3(0, -1000, 0)
	add_child(well)
	well.grav_param       = 9_800_000.0
	well.influence_radius = 2000.0
	_well = well

# ── HUD ─────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	_hud = Label.new()
	_hud.position = Vector2(14, 10)
	_hud.add_theme_font_size_override("font_size", 12)
	_hud.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	canvas.add_child(_hud)
	add_child(canvas)

func _process(_delta: float) -> void:
	if not is_instance_valid(_player): return
	_update_proximity()
	_update_hud()

func _update_proximity() -> void:
	_near_upgrade = -1
	_near_launch  = false
	var pp := _player.global_position
	for i in _upgrade_positions.size():
		if pp.distance_to(_upgrade_positions[i]) < 3.0:
			_near_upgrade = i
			break
	if pp.distance_to(Vector3(0, 0, 9)) < 4.0:
		_near_launch = true

func _update_hud() -> void:
	var lines: Array[String] = [
		"SHIPYARD   ·   WASD WALK  ·  SPACE JETPACK",
		"Woolongs: %d ₩" % _woolongs,
	]
	if _near_upgrade >= 0:
		var ud    := UPGRADES[_near_upgrade]
		var owned := _upgrades.get(ud["id"], false)
		if owned:
			lines.append("✓ %s — ALREADY INSTALLED" % ud["name"])
		elif _woolongs >= ud["cost"]:
			lines.append("[ F ] BUY  %s  —  %d ₩" % [ud["name"], ud["cost"]])
		else:
			lines.append("%s  —  %d ₩  (need %d more)" % [ud["name"], ud["cost"], ud["cost"] - _woolongs])
	elif _near_launch:
		lines.append("[ G ] LAUNCH — return to ship")
	_hud.text = "\n".join(lines)

# ── input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var ke := event as InputEventKey
	if ke.keycode == KEY_F and _near_upgrade >= 0:
		_buy_upgrade(_near_upgrade)
	elif ke.keycode == KEY_G and _near_launch:
		_launch()

func _buy_upgrade(idx: int) -> void:
	## MUTATE_GLOBAL — deducts woolongs, sets upgrade flag, saves
	var ud    := UPGRADES[idx]
	if _upgrades.get(ud["id"], false): return   # already owned
	if _woolongs < ud["cost"]: return            # can't afford
	_woolongs -= ud["cost"]
	_upgrades[ud["id"]] = true
	_save_to_game_state()
	# Rebuild bays so labels + lights update
	_rebuild_upgrade_bay_labels(idx)

func _rebuild_upgrade_bay_labels(idx: int) -> void:
	## TREE_STRUCTURE — cheaply update only the label text after a purchase
	# Full rebuild is expensive; just update the cost label by recreating it
	# (Labels are cheap, no collision shapes involved)
	var ud   := UPGRADES[idx]
	var pos  := _upgrade_positions[idx]
	# Remove old name + desc labels by querying children at that position
	# (Simpler: just set text on existing labels — but we don't hold refs)
	# Acceptable trade-off: full redraw of bay visuals
	_rebuild_all_bays()

func _rebuild_all_bays() -> void:
	## TREE_STRUCTURE — clear and redraw all upgrade bay meshes/labels
	# Collect nodes to remove (everything tagged as bay children)
	# Since we don't tag them, just reload the scene — but we can't change_scene on self.
	# So we re-build: remove Label3D and MeshInstance3D children near bay positions, re-add.
	# Quick approach: remove all Label3D and non-collision MeshInstance3D children
	for child in get_children():
		if child is Label3D or (child is MeshInstance3D and child.position.z < -5.0):
			child.queue_free()
	await get_tree().process_frame
	_build_upgrade_bays()
	_build_launch_pad()   # pad label is also Label3D
	# Rebuild shipyard sign + sub
	var sign := Label3D.new()
	sign.text       = "SHIPYARD"
	sign.pixel_size = 0.022
	sign.position   = Vector3(0, 6.0, -10.5)
	sign.rotation_degrees = Vector3(0, 180, 0)
	sign.modulate   = ACCENT
	add_child(sign)
	var sub := Label3D.new()
	sub.text       = "UPGRADE YOUR VESSEL · PAY IN WOOLONGS"
	sub.pixel_size = 0.010
	sub.position   = Vector3(0, 5.3, -10.5)
	sub.rotation_degrees = Vector3(0, 180, 0)
	sub.modulate   = CYAN
	add_child(sub)

func _launch() -> void:
	_save_to_game_state()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# ── player spawn ─────────────────────────────────────────────────────────────

func _spawn_player() -> void:
	var p   := CharacterBody3D.new()
	p.set_script(load("res://scripts/player_body.gd"))
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38; cap.height = 1.70
	var col := CollisionShape3D.new()
	col.shape = cap
	p.add_child(col)
	p.position = Vector3(0, 1.2, 9)   # near launch pad
	add_child(p)
	_player = p
	if is_instance_valid(_well):
		_player.call("add_well", _well)

# ── helpers ──────────────────────────────────────────────────────────────────

func _slab(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new()
	bm.size = size; mi.mesh = bm; mi.position = pos; mi.material_override = mat
	var body := StaticBody3D.new(); var col := CollisionShape3D.new()
	var box  := BoxShape3D.new(); box.size = size; col.shape = box; col.position = pos
	add_child(body); body.add_child(col); add_child(mi)

func _wall(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new()
	bm.size = size; mi.mesh = bm; mi.position = pos; mi.material_override = mat
	add_child(mi)

func _mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col; m.roughness = rough; m.metallic = metal
	return m

func _emit_mat(albedo: Color, emit: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo; m.emission_enabled = true
	m.emission = emit; m.emission_energy_multiplier = energy; m.roughness = 0.3
	return m
