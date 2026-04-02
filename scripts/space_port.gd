extends Node3D
## SpacePort — BooBies Station interior (Space Dandy aesthetic)
## TREE_STRUCTURE — builds everything in code, self-contained scene
##
## Gravity: artificial floor gravity (constant ~9.8 m/s²), well 1 km below
## Market: 3 booths, walk to counter, F=buy, SHIFT+F=sell
## [ G ] at Departure Bay → snapshot state → change_scene_to main.tscn

const BOOTH_DATA: Array[Dictionary] = [
	{"name": "FOOD & DRINKS",  "good": "Food & Drinks",  "buy": 45,  "sell": 28,  "color": Color(1.0, 0.25, 0.55)},
	{"name": "BIO-SAMPLES",    "good": "Bio-samples",    "buy": 340, "sell": 220, "color": Color(0.10, 0.80, 0.95)},
	{"name": "RARE ALIENS",    "good": "Rare Aliens",    "buy": 950, "sell": 700, "color": Color(0.55, 0.10, 1.00)},
]

const BOOTH_X   := 13.0
const WALL_MAT  := Color(0.06, 0.04, 0.10)
const FLOOR_MAT := Color(0.11, 0.07, 0.16)
const PINK      := Color(1.00, 0.10, 0.55)
const CYAN      := Color(0.10, 0.80, 0.95)
const YELLOW    := Color(1.00, 0.80, 0.10)

var _player: PlayerBody      = null
var _well:   GravityWell     = null
var _hud:    Label           = null
var _near_booth: int         = -1   # index into BOOTH_DATA, -1 = none
var _near_launch: bool       = false
var _near_clerk:  bool       = false
var _pending_aliens: Array   = []   # [{id, woolongs}] — brought from space, collect at desk
var _credits: int            = 0
var _cargo:   Dictionary     = {}
var _woolongs: int           = 0
var _booth_positions: Array[Vector3] = []

func _ready() -> void:
	_load_from_game_state()
	_build_environment()
	_build_floor_and_walls()
	_build_booths()
	_build_registration_desk()
	_build_departure_bay()
	_build_neon_trim()
	_build_gravity()
	_build_npcs()
	_build_hud()
	_spawn_player()

# ── GameState integration ──────────────────────────────────────────────────

func _load_from_game_state() -> void:
	if not has_node("/root/GameState"): return
	var gs := get_node("/root/GameState")
	_credits        = gs.credits
	_cargo          = gs.cargo.duplicate()
	_woolongs       = gs.woolongs
	_pending_aliens = gs.pending_aliens.duplicate()

func _save_to_game_state() -> void:
	if not has_node("/root/GameState"): return
	var gs   := get_node("/root/GameState")
	gs.credits  = _credits
	gs.cargo    = _cargo.duplicate()
	gs.woolongs = _woolongs
	gs.save_game()

# ── environment ────────────────────────────────────────────────────────────

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = Color(0.005, 0.003, 0.010, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.28, 0.06, 0.32)
	env.ambient_light_energy = 0.5
	env.glow_enabled   = true
	env.glow_intensity = 1.4
	env.glow_bloom     = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

# ── floor and walls ────────────────────────────────────────────────────────

func _build_floor_and_walls() -> void:
	var fw  := _mat(FLOOR_MAT, 0.85, 0.1)
	var wm  := _mat(WALL_MAT,  0.90, 0.05)
	var ceil_m := _mat(Color(0.04, 0.03, 0.07), 0.90, 0.0)

	# Main concourse  -10 to +14 z, ±16 x, 0 to 6 y
	_slab(Vector3(32, 0.3, 24), Vector3(0, -0.15, 2), fw)       # floor
	_slab(Vector3(32, 0.3, 24), Vector3(0,  6.15, 2), ceil_m)   # ceiling
	_wall(Vector3(0.3, 6, 24), Vector3(-16, 3, 2), wm)           # left wall
	_wall(Vector3(0.3, 6, 24), Vector3( 16, 3, 2), wm)           # right wall
	_wall(Vector3(32, 6, 0.3), Vector3(0, 3, -10), wm)           # back wall

	# Airlock entry corridor  -18 to -10 z, ±5 x
	_slab(Vector3(10, 0.3,  8), Vector3(0, -0.15, -14), fw)
	_slab(Vector3(10, 0.3,  8), Vector3(0,  5.15, -14), ceil_m)
	_wall(Vector3(0.3, 5, 8), Vector3(-5, 2.5, -14), wm)
	_wall(Vector3(0.3, 5, 8), Vector3( 5, 2.5, -14), wm)
	_wall(Vector3(10, 5, 0.3), Vector3(0, 2.5, -18), wm)   # entry door wall

	# Departure tube  +14 to +22 z, ±5 x
	_slab(Vector3(10, 0.3,  8), Vector3(0, -0.15, 18), fw)
	_slab(Vector3(10, 0.3,  8), Vector3(0,  5.15, 18), ceil_m)
	_wall(Vector3(0.3, 5, 8), Vector3(-5, 2.5, 18), wm)
	_wall(Vector3(0.3, 5, 8), Vector3( 5, 2.5, 18), wm)
	_wall(Vector3(10, 5, 0.3), Vector3(0, 2.5, 22), wm)   # far end wall

	# Flood lights along concourse ceiling
	for z: float in [-4.0, 2.0, 8.0]:
		var l := OmniLight3D.new()
		l.position     = Vector3(0, 5.5, z)
		l.light_color  = Color(0.9, 0.5, 0.95)
		l.light_energy = 3.0
		l.omni_range   = 14.0
		add_child(l)
	# Entry + departure lights (white-ish)
	for z2: float in [-14.0, 18.0]:
		var l2 := OmniLight3D.new()
		l2.position    = Vector3(0, 4.5, z2)
		l2.light_color = Color(0.95, 0.90, 1.0)
		l2.light_energy = 2.0
		l2.omni_range  = 12.0
		add_child(l2)

# ── vendor booths ──────────────────────────────────────────────────────────

func _build_booths() -> void:
	_booth_positions.clear()
	var zs: Array[float] = [-4.0, 2.0, 8.0]
	for i in BOOTH_DATA.size():
		var data   := BOOTH_DATA[i]
		var z      := zs[i]
		var bpos   := Vector3(BOOTH_X, 0, z)
		_booth_positions.append(bpos)

		var cm  := _mat(data["color"].darkened(0.5), 0.5, 0.3)
		var em  := _emit_mat(data["color"], data["color"], 1.8)

		# Counter slab
		_slab(Vector3(4, 1.1, 3), bpos + Vector3(-2, 0.55, 0), cm)
		# Back wall of booth
		_wall(Vector3(0.2, 4, 3.2), bpos + Vector3(-0.0, 2, 0), _mat(WALL_MAT.darkened(0.2), 0.9, 0))
		# Neon name sign on back wall
		var lbl := Label3D.new()
		lbl.text       = data["name"]
		lbl.pixel_size = 0.012
		lbl.position   = bpos + Vector3(-0.2, 3.2, 0)
		lbl.rotation_degrees = Vector3(0, 180, 0)
		lbl.modulate   = data["color"]
		lbl.billboard  = BaseMaterial3D.BILLBOARD_DISABLED
		add_child(lbl)
		# Emissive price strip on counter edge
		_wall(Vector3(0.08, 0.12, 2.8), bpos + Vector3(-0.04, 1.12, 0), em)
		# Booth light
		var bl := OmniLight3D.new()
		bl.position    = bpos + Vector3(-1, 3, 0)
		bl.light_color = data["color"]
		bl.light_energy = 2.0
		bl.omni_range  = 6.0
		add_child(bl)

# ── alien registration desk ────────────────────────────────────────────────

func _build_registration_desk() -> void:
	var dm  := _mat(Color(0.14, 0.08, 0.20), 0.6, 0.3)
	var em  := _emit_mat(PINK, PINK, 1.2)

	# Desk
	_slab(Vector3(5, 1.1, 2.5), Vector3(-13, 0.55, 2), dm)

	# "ALIEN REGISTRATION CENTER" sign above desk
	var sign := Label3D.new()
	sign.text       = "ALIEN\nREGISTRATION\nCENTER"
	sign.pixel_size = 0.014
	sign.position   = Vector3(-14.5, 3.8, 2)
	sign.rotation_degrees = Vector3(0, 90, 0)
	sign.modulate   = PINK
	add_child(sign)

	# "NPC" silhouette behind desk — just dark boxes suggesting a figure
	var npm  := _mat(Color(0.08, 0.05, 0.12), 0.8, 0)
	_slab(Vector3(0.5, 1.4, 0.3),  Vector3(-14.6, 0.7, 2), npm)   # torso
	_slab(Vector3(0.38, 0.38, 0.38), Vector3(-14.6, 1.6, 2), npm)  # head
	# Pink glow strip on desk edge
	_wall(Vector3(4.8, 0.08, 0.08), Vector3(-13, 1.14, 1.0), em)

	# Desk light
	var dl := OmniLight3D.new()
	dl.position    = Vector3(-12, 3.5, 2)
	dl.light_color = PINK
	dl.light_energy = 2.5
	dl.omni_range  = 8.0
	add_child(dl)

# ── departure bay ──────────────────────────────────────────────────────────

func _build_departure_bay() -> void:
	# Floor marker — glowing pad
	var pad_m := _emit_mat(Color(0.4, 0.6, 1.0), Color(0.3, 0.5, 1.0), 0.8)
	_slab(Vector3(4, 0.05, 4), Vector3(0, 0.025, 19), pad_m)

	# "LAUNCH BAY" neon
	var sign := Label3D.new()
	sign.text       = "[ G ]  LAUNCH\nLAUNCH BAY · ALOHA OE"
	sign.pixel_size = 0.016
	sign.position   = Vector3(0, 4.0, 21.5)
	sign.rotation_degrees = Vector3(0, 180, 0)
	sign.modulate   = CYAN
	sign.billboard  = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(sign)

	# Launch pad light
	var ll := OmniLight3D.new()
	ll.position    = Vector3(0, 4.5, 19)
	ll.light_color = Color(0.4, 0.6, 1.0)
	ll.light_energy = 3.5
	ll.omni_range  = 8.0
	add_child(ll)

# ── neon trim strips ───────────────────────────────────────────────────────

func _build_neon_trim() -> void:
	var pe := _emit_mat(PINK, PINK, 2.0)
	var ce := _emit_mat(CYAN, CYAN, 1.5)

	# Pink floor-level strip along left wall
	_wall(Vector3(0.06, 0.08, 23.5), Vector3(-15.88, 0.2, 2), pe)
	# Cyan floor-level strip along right wall
	_wall(Vector3(0.06, 0.08, 23.5), Vector3( 15.88, 0.2, 2), ce)
	# Ceiling strip center
	_wall(Vector3(0.06, 0.08, 23.5), Vector3(0, 5.9, 2), pe)

# ── gravity ────────────────────────────────────────────────────────────────

func _build_gravity() -> void:
	# Well far below floor — gives near-constant floor gravity (~9.8 m/s²)
	_well = GravityWell.new()
	_well.position = Vector3(0, -1000, 0)
	add_child(_well)
	# Override computed grav_param: g * d² = 9.8 * 1000² = 9,800,000
	_well.grav_param      = 9_800_000.0
	_well.influence_radius = 2000.0

# ── HUD ───────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	_hud = Label.new()
	_hud.position = Vector2(14, 10)
	_hud.add_theme_font_size_override("font_size", 12)
	_hud.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85))
	canvas.add_child(_hud)
	add_child(canvas)

func _process(_delta: float) -> void:
	if not is_instance_valid(_player): return
	_update_proximity()
	_update_hud_text()

func _update_proximity() -> void:
	_near_booth   = -1
	_near_launch  = false
	_near_clerk   = false
	var pp := _player.global_position
	for i in BOOTH_DATA.size():
		if pp.distance_to(_booth_positions[i]) < 3.5:
			_near_booth = i
			break
	if pp.distance_to(Vector3(0, 0, 19)) < 4.0:
		_near_launch = true
	if pp.distance_to(Vector3(-14.6, 1.0, 2.0)) < 3.5:
		_near_clerk = true

func _update_hud_text() -> void:
	var total_cargo: int = 0
	for v in _cargo.values(): total_cargo += v
	var lines: Array[String] = [
		"BOOBIES STATION   ·   WASD WALK  ·  SPACE JETPACK",
		"Credits: %d ₩   Woolongs: %d   Cargo: %d/20" % [_credits, _woolongs, total_cargo],
	]
	if _near_clerk:
		if _pending_aliens.size() > 0:
			var total_w: int = 0
			for a in _pending_aliens: total_w += int(a["woolongs"])
			lines.append("[ F ] REGISTER %d ALIEN(S) — COLLECT +%d WOOLONGS" % [
				_pending_aliens.size(), total_w])
		else:
			lines.append("ALIEN REGISTRATION DESK — nothing to register")
	elif _near_booth >= 0:
		var bd := BOOTH_DATA[_near_booth]
		var have: int = _cargo.get(bd["good"], 0)
		lines.append("[ F ] BUY %s  %d₩   [ SHIFT+F ] SELL  %d₩   (have %d)" % [
			bd["good"], bd["buy"], bd["sell"], have])
	elif _near_launch:
		lines.append("[ G ] LAUNCH — return to ship")
	_hud.text = "\n".join(lines)

# ── input ─────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var ke := event as InputEventKey
	if ke.keycode == KEY_F and _near_clerk:
		_do_registration()
	elif ke.keycode == KEY_F and _near_booth >= 0:
		_trade(BOOTH_DATA[_near_booth], ke.shift_pressed)
	elif ke.keycode == KEY_G and _near_launch:
		_launch()

func _do_registration() -> void:
	## MUTATE_GLOBAL — collect pending alien bounties at CLERK desk
	if _pending_aliens.is_empty(): return
	var earned: int = 0
	for a in _pending_aliens:
		earned += int(a["woolongs"])
	_woolongs += earned
	_pending_aliens.clear()
	if has_node("/root/GameState"):
		var gs := get_node("/root/GameState")
		gs.woolongs        = _woolongs
		gs.pending_aliens  = []
		gs.save_game()

func _trade(bd: Dictionary, is_sell: bool) -> void:
	if is_sell:
		var have: int = _cargo.get(bd["good"], 0)
		if have <= 0: return
		_cargo[bd["good"]] -= 1
		if _cargo[bd["good"]] == 0: _cargo.erase(bd["good"])
		_credits += bd["sell"]
	else:
		var total: int = 0
		for v in _cargo.values(): total += v
		if total >= 20 or _credits < bd["buy"]: return
		_credits -= bd["buy"]
		_cargo[bd["good"]] = _cargo.get(bd["good"], 0) + 1
	_save_to_game_state()

func _launch() -> void:
	_save_to_game_state()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# ── alien NPCs ─────────────────────────────────────────────────────────────
## Node3D bodies — no physics, patrol via looping Tweens.
## Types match space_world alien manifest (Space Dandy aesthetic).

func _build_npcs() -> void:
	## TREE_STRUCTURE — 4 alien characters: clerk, barista, 2 patrons
	# Registration Clerk — replaces static dark-box silhouette
	_npc_humanoid(
		Vector3(-14.6, 0.0, 2.0),
		Color(0.65, 0.10, 0.80),   # purple alien
		"CLERK",
		[],   # stationary
		true  # facing +X (toward player)
	)
	# Barista — behind Food & Drinks booth (z=-4, counter on right wall)
	_npc_orb(
		Vector3(15.2, 1.4, -4.0),
		Color(1.0, 0.55, 0.1),    # warm orange cat-type orb
		"BARB",
		[]    # stationary
	)
	# Patron A — walks the concourse length (z: -6 to +10)
	_npc_humanoid(
		Vector3(-4.0, 0.0, -6.0),
		Color(0.18, 0.75, 0.35),   # green Plantian
		"GUGU",
		[Vector3(-4.0, 0.0, -6.0), Vector3(-4.0, 0.0, 10.0)],
		false
	)
	# Patron B — small round Betelgeusian, drifts between booths
	_npc_orb(
		Vector3(8.0, 1.8, -2.0),
		Color(0.95, 0.85, 0.20),   # gold shimmer
		"MEOW",
		[Vector3(8.0, 1.8, -2.0), Vector3(8.0, 1.8, 8.0), Vector3(5.0, 1.8, 4.0)]
	)

func _npc_humanoid(start: Vector3, color: Color, npc_name: String,
		waypoints: Array, face_right: bool) -> void:
	## TREE_STRUCTURE — bipedal alien NPC: torso + head + name tag
	var root := Node3D.new()
	root.position = start
	if face_right: root.rotation_degrees.y = 90.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color.darkened(0.3)
	mat.emission_energy_multiplier = 0.4
	mat.roughness = 0.6

	# Torso
	var t_m := CapsuleMesh.new(); t_m.radius = 0.22; t_m.height = 1.0; t_m.material = mat
	var t   := MeshInstance3D.new(); t.mesh = t_m; t.position = Vector3(0, 0.8, 0)
	root.add_child(t)
	# Head
	var h_m := SphereMesh.new(); h_m.radius = 0.19; h_m.height = 0.38
	h_m.radial_segments = 8; h_m.rings = 5; h_m.material = mat
	var h   := MeshInstance3D.new(); h.mesh = h_m; h.position = Vector3(0, 1.52, 0)
	root.add_child(h)
	# Glow eyes
	var eye_m := StandardMaterial3D.new()
	eye_m.albedo_color = Color(1.0, 1.0, 1.0)
	eye_m.emission_enabled = true; eye_m.emission = color.lightened(0.4)
	eye_m.emission_energy_multiplier = 2.0
	for ex: float in [-0.07, 0.07]:
		var em := SphereMesh.new(); em.radius = 0.04; em.height = 0.08
		em.radial_segments = 4; em.rings = 2; em.material = eye_m
		var e  := MeshInstance3D.new(); e.mesh = em
		e.position = Vector3(ex, 1.56, -0.16)
		root.add_child(e)
	# Name tag
	var lbl := Label3D.new(); lbl.text = npc_name; lbl.pixel_size = 0.010
	lbl.position = Vector3(0, 1.95, 0); lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = color.lightened(0.3)
	root.add_child(lbl)

	add_child(root)
	if waypoints.size() >= 2:
		_start_patrol(root, waypoints, 3.5)

func _npc_orb(start: Vector3, color: Color, npc_name: String, waypoints: Array) -> void:
	## TREE_STRUCTURE — floating orb alien: sphere body + halo ring + name tag
	var root := Node3D.new()
	root.position = start

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color; mat.roughness = 0.2; mat.metallic = 0.3
	mat.emission_enabled = true; mat.emission = color
	mat.emission_energy_multiplier = 0.6

	var body_m := SphereMesh.new(); body_m.radius = 0.32; body_m.height = 0.64
	body_m.radial_segments = 10; body_m.rings = 6; body_m.material = mat
	var body := MeshInstance3D.new(); body.mesh = body_m
	root.add_child(body)

	# Halo ring
	var halo_m := TorusMesh.new(); halo_m.inner_radius = 0.35; halo_m.outer_radius = 0.42
	halo_m.rings = 16; halo_m.ring_segments = 8
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(color.r, color.g, color.b, 0.5)
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.emission_enabled = true; halo_mat.emission = color.lightened(0.2)
	halo_mat.emission_energy_multiplier = 1.2
	halo_m.material = halo_mat
	var halo := MeshInstance3D.new(); halo.mesh = halo_m; halo.rotation_degrees.x = 90
	root.add_child(halo)

	# Name tag
	var lbl := Label3D.new(); lbl.text = npc_name; lbl.pixel_size = 0.009
	lbl.position = Vector3(0, 0.65, 0); lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = color.lightened(0.4)
	root.add_child(lbl)

	add_child(root)

	# Orbs bob up/down continuously
	var bob := create_tween().set_loops()
	bob.tween_property(root, "position:y", start.y + 0.22, 1.8).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(root, "position:y", start.y - 0.22, 1.8).set_ease(Tween.EASE_IN_OUT)
	# Halo spins
	var spin := create_tween().set_loops()
	spin.tween_property(halo, "rotation_degrees:y", 360.0, 4.0).as_relative()

	if waypoints.size() >= 2:
		_start_patrol(root, waypoints, 2.5)

func _start_patrol(npc: Node3D, waypoints: Array, speed: float) -> void:
	## MUTATE_GLOBAL — creates a looping Tween that walks npc through waypoints
	var t := create_tween().set_loops()
	for i in waypoints.size():
		var dest: Vector3 = waypoints[i]
		var next: Vector3 = waypoints[(i + 1) % waypoints.size()]
		var dist := dest.distance_to(next)
		var dur  := maxf(dist / speed, 0.1)
		# face direction of travel
		var dir  := (next - dest)
		if dir.length() > 0.01:
			var angle := atan2(dir.x, dir.z)
			t.tween_property(npc, "rotation:y", angle, 0.25)
		t.tween_property(npc, "position", next, dur).set_ease(Tween.EASE_IN_OUT)
		t.tween_interval(0.8)   # pause at each waypoint

# ── player spawn ───────────────────────────────────────────────────────────

func _spawn_player() -> void:
	var p   := CharacterBody3D.new()
	p.set_script(load("res://scripts/player_body.gd"))
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38; cap.height = 1.70
	var col := CollisionShape3D.new()
	col.shape = cap
	p.add_child(col)
	p.position = Vector3(0, 1.2, -13)   # entrance side
	add_child(p)
	_player = p as PlayerBody
	if is_instance_valid(_well):
		_player.call("add_well", _well)

# ── helpers ───────────────────────────────────────────────────────────────

func _slab(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi   := MeshInstance3D.new()
	var bm   := BoxMesh.new()
	bm.size  = size
	mi.mesh  = bm
	mi.position = pos
	mi.material_override = mat
	var body := StaticBody3D.new()
	var col  := CollisionShape3D.new()
	var box  := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	add_child(body)
	body.add_child(col)
	add_child(mi)

func _wall(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi   := MeshInstance3D.new()
	var bm   := BoxMesh.new()
	bm.size  = size
	mi.mesh  = bm
	mi.position = pos
	mi.material_override = mat
	add_child(mi)

func _mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness    = rough
	m.metallic     = metal
	return m

func _emit_mat(albedo: Color, emit: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color              = albedo
	m.emission_enabled          = true
	m.emission                  = emit
	m.emission_energy_multiplier = energy
	m.roughness                 = 0.3
	return m
