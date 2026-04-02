extends Node3D
# FRONTIER × SPACE DANDY — Ship controller
# Flight model lifted from Elite: Frontier. Aesthetic lifted from Space Dandy.
# He's a dandy guy in space, and so are you.

# ── flight constants ───────────────────────────────────────────────────────

var MAX_SPEED      : float = 380.0    # upgradeable — Engine MK2
var BOOST_SPEED    : float = 1100.0   # upgradeable — Engine MK2
const THRUST         := 160.0
const STRAFE_THRUST  := 85.0
const ROT_SPEED      := 1.55
const BOOST_DURATION := 4.5
const BOOST_COOLDOWN := 11.0
var SCAN_RANGE       : float = 500.0  # upgradeable — Scanner+

# ── flight state ───────────────────────────────────────────────────────────

var velocity: Vector3       = Vector3.ZERO
var throttle: float         = 0.0
var flight_assist: bool     = true
var _boosting: bool         = false
var _boost_timer: float     = 0.0
var _boost_cooldown: float  = 0.0

# ── alien registry ─────────────────────────────────────────────────────────

var _registered: Array[String] = []   # alien IDs already scanned
var _woolongs:   int           = 0
var _scan_timer: float         = 0.0
var _scan_msg:   String        = ""
var _targets:    Array         = []   # [{name, pos}] cycled with T
var _target_idx: int           = 0

# ── economy ────────────────────────────────────────────────────────────────

var _credits: int      = 1000
var _cargo: Dictionary = {}
var _cargo_max: int    = 20

# ── locations + docking ────────────────────────────────────────────────────

var _locations: Array   = []
var _nearby_location    = null   # Location node or null
var _docked: bool       = false
var _docked_location    = null   # Location we're docked at
var _parked: bool       = false  # on foot — ship sitting still, cameras disabled

# ── gravity ────────────────────────────────────────────────────────────────

var _wells: Array           = []
var _gravity_accel: Vector3 = Vector3.ZERO

# ── nodes ──────────────────────────────────────────────────────────────────

var _ship_mesh: Node3D
var _cam_cockpit: Camera3D
var _cam_external: Camera3D
var _external_view: bool = false
var _engine_light_l: OmniLight3D
var _engine_light_r: OmniLight3D

# ── hud nodes ──────────────────────────────────────────────────────────────

var _speed_fill:    ColorRect
var _speed_label:   Label
var _throttle_fill: ColorRect
var _boost_label:   Label
var _fa_label:      Label
var _target_label:  Label
var _dist_label:    Label
var _scan_label:    Label   # temp scan result display
var _woolong_label: Label   # woolong counter
var _reg_label:     Label   # X / 5 registered

var _dock_hint_label: Label
var _hud_root: Control
var _market_panel: Control
var _market_title: Label
var _market_credits_label: Label
var _market_rows: Array[Label] = []
var _market_cargo_label: Label
var _waypoint_marker: Label
var _cargo_hud_label: Label
var _objective_label: Label
var _objective_timer: float = 7.0
var _clock_label: Label        # game time display
var _shipyard_panel: Control   # upgrade shop — only at BooBies

# ── hud color — hue-driven, H key to slide ────────────────────────────────
# degrees: 0=red  30=orange  60=gold  120=green  200=cyan  280=purple  320=pink

var _hue_h:     float = 30.0
var MAIN:       Color = Color(1.00, 0.50, 0.05, 1.0)
var MAIN_DIM:   Color = Color(0.40, 0.20, 0.02, 1.0)
var MAIN_BRIGHT: Color = Color(1.00, 0.76, 0.50, 1.0)
const CYAN        := Color(0.10, 0.90, 0.95, 1.0)
const YELLOW      := Color(1.00, 0.80, 0.10, 1.0)

func _ready() -> void:
	_build_ship_mesh()
	_build_cameras()
	_build_hud()
	_build_terminal()
	_set_view(false)
	_build_target_list()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Load persistent state from GameState
	if has_node("/root/GameState"):
		var gs := get_node("/root/GameState")
		_credits    = gs.credits
		_cargo      = gs.cargo.duplicate()
		_woolongs   = gs.woolongs
		_registered = gs.registered_aliens.duplicate()
		_apply_upgrades(gs)

# ── ship terminal ──────────────────────────────────────────────────────────

func _build_terminal() -> void:
	## TREE_STRUCTURE — attach ship computer terminal (backtick to toggle)
	var t := Node.new()
	t.set_script(load("res://scripts/ship_terminal.gd"))
	t.name = "ShipTerminal"
	add_child(t)

# ── target list (built after world passes metadata) ────────────────────────

func _build_target_list() -> void:
	_targets.clear()
	if has_meta("boobie_pos"):
		_targets.append({"name": "BOOBIES", "pos": get_meta("boobie_pos")})
	if has_meta("alien_data"):
		for a: Dictionary in get_meta("alien_data"):
			_targets.append({"name": a["id"], "pos": a["pos"]})
	_locations.clear()
	if has_meta("location_nodes"):
		for loc in get_meta("location_nodes"):
			_locations.append(loc)

# ── ship mesh — Aloha Oe vibes ─────────────────────────────────────────────

func _build_ship_mesh() -> void:
	_ship_mesh = Node3D.new()
	add_child(_ship_mesh)

	var hull_mat   := _mat(Color(0.22, 0.20, 0.26), 0.60, 0.80)
	var dark_mat   := _mat(Color(0.12, 0.10, 0.14), 0.75, 0.55)
	var red_mat    := _mat(Color(0.72, 0.05, 0.12), 0.50, 0.60)   # dandy red accent

	# Main fuselage
	_box(_ship_mesh, Vector3(1.05, 0.30, 2.80), Vector3.ZERO, hull_mat)
	# Underbelly
	_box(_ship_mesh, Vector3(0.90, 0.06, 2.40), Vector3(0, -0.17, 0.10), dark_mat)
	# Nose
	_box(_ship_mesh, Vector3(0.40, 0.20, 0.95), Vector3(0, 0.03, -1.75), hull_mat)

	# Red racing stripe along the fuselage sides — the dandy touch
	_box(_ship_mesh, Vector3(0.04, 0.26, 2.60), Vector3( 0.52, 0.0, 0.0), red_mat)
	_box(_ship_mesh, Vector3(0.04, 0.26, 2.60), Vector3(-0.52, 0.0, 0.0), red_mat)

	# THE POMPADOUR — tall dorsal fin (Dandy's hair, but for a ship)
	_box(_ship_mesh, Vector3(0.18, 0.55, 1.40), Vector3(0,  0.42,  0.0), hull_mat)   # base
	_box(_ship_mesh, Vector3(0.14, 0.38, 0.90), Vector3(0,  0.82, -0.20), hull_mat)   # mid
	_box(_ship_mesh, Vector3(0.10, 0.24, 0.45), Vector3(0,  1.08, -0.42), red_mat)    # tip (red)

	# Delta wings
	for side: float in [-1.0, 1.0]:
		var wpos := Vector3(side * 1.30, -0.07, 0.28)
		var wing := _box(_ship_mesh, Vector3(1.55, 0.055, 1.70), wpos, dark_mat)
		wing.rotation.z = side * deg_to_rad(5.5)
		wing.rotation.y = side * deg_to_rad(11.0)
		# Wingtip vane
		_box(_ship_mesh, Vector3(0.10, 0.22, 0.48),
			wpos + Vector3(side * 0.72, 0.06, -0.15), hull_mat)
		# Red underwing stripe
		_box(_ship_mesh, Vector3(1.40, 0.03, 0.06),
			wpos + Vector3(0, -0.04, -0.45), red_mat)

	# Cockpit canopy — pink-tinted for dandy style
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color              = Color(0.55, 0.12, 0.35, 0.45)
	canopy_mat.emission_enabled          = true
	canopy_mat.emission                  = Color(0.80, 0.08, 0.40)
	canopy_mat.emission_energy_multiplier= 0.55
	canopy_mat.roughness                 = 0.05
	canopy_mat.metallic                  = 0.0
	canopy_mat.transparency              = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(_ship_mesh, Vector3(0.52, 0.17, 0.54), Vector3(0, 0.232, -0.52), canopy_mat)

	# Thruster pods + pink engine glow
	for side: float in [-1.0, 1.0]:
		var tpos := Vector3(side * 0.30, -0.04, 1.28)
		_box(_ship_mesh, Vector3(0.26, 0.25, 0.42), tpos, dark_mat)

		var noz   := MeshInstance3D.new()
		var cyl   := CylinderMesh.new()
		cyl.top_radius    = 0.095
		cyl.bottom_radius = 0.125
		cyl.height        = 0.22
		noz.mesh          = cyl
		noz.position      = tpos + Vector3(0, 0, 0.30)
		noz.rotation.x    = deg_to_rad(90)
		noz.material_override = _mat(Color(0.04, 0.04, 0.06), 0.88, 0.15)
		_ship_mesh.add_child(noz)

		# Pink/magenta engine glow — Space Dandy signature
		var gm := MeshInstance3D.new()
		var gs := SphereMesh.new()
		gs.radius = 0.09; gs.height = 0.18
		gm.mesh = gs
		gm.position = tpos + Vector3(0, 0, 0.45)
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color              = Color(0.85, 0.15, 0.65)
		gmat.emission_enabled          = true
		gmat.emission                  = Color(1.0, 0.15, 0.70)
		gmat.emission_energy_multiplier= 4.0
		gmat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.material_override = gmat
		_ship_mesh.add_child(gm)

		var el := OmniLight3D.new()
		el.position    = tpos + Vector3(0, 0, 0.55)
		el.light_color = Color(0.9, 0.15, 0.65)
		el.light_energy= 1.8
		el.omni_range  = 6.0
		_ship_mesh.add_child(el)
		if side < 0.0: _engine_light_l = el
		else:          _engine_light_r = el

# ── cameras ────────────────────────────────────────────────────────────────

func _build_cameras() -> void:
	_cam_cockpit = Camera3D.new()
	_cam_cockpit.position = Vector3(0, 0.19, -0.45)
	_cam_cockpit.fov  = 88
	_cam_cockpit.far  = 200000.0
	add_child(_cam_cockpit)

	_cam_external = Camera3D.new()
	_cam_external.position = Vector3(0, 3.8, 11.5)
	_cam_external.rotation_degrees = Vector3(-9, 0, 0)
	_cam_external.fov  = 72
	_cam_external.far  = 200000.0
	add_child(_cam_external)

func _set_view(external: bool) -> void:
	_external_view    = external
	_cam_cockpit.current  = not external
	_cam_external.current = external
	_ship_mesh.visible    = external

# ── input ──────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _parked: return
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			rotate_object_local(Vector3.UP,    -event.relative.x * 0.0013)
			rotate_object_local(Vector3.RIGHT, -event.relative.y * 0.0013)

func _input(event: InputEvent) -> void:
	if _parked: return
	if not (event is InputEventKey): return
	if not (event as InputEventKey).pressed: return
	match (event as InputEventKey).keycode:
		KEY_V:
			_set_view(not _external_view)
		KEY_TAB:
			flight_assist = not flight_assist
		KEY_SPACE:
			if _boost_cooldown <= 0.0 and not _boosting:
				_boosting    = true
				_boost_timer = BOOST_DURATION
		KEY_R:
			_do_scan()
		KEY_T:
			if _targets.size() > 0:
				_target_idx = (_target_idx + 1) % _targets.size()
		KEY_L:
			if _docked:
				_undock()
			elif _nearby_location != null:
				_dock(_nearby_location)
		KEY_G:
			if _docked and _docked_location != null:
				# Works for PLANET (on-foot surface) and STATION (interior scene)
				get_parent().request_exit_ship(self, _docked_location)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			if _docked:
				var idx: int = (event as InputEventKey).keycode - KEY_1
				_market_trade(idx, Input.is_key_pressed(KEY_SHIFT))
		KEY_ESCAPE:
			get_tree().quit()

# ── scan ───────────────────────────────────────────────────────────────────

func _do_scan() -> void:
	if not has_meta("alien_data"): return
	var aliens: Array = get_meta("alien_data")
	var closest_dist := SCAN_RANGE + 1.0
	var found: Dictionary = {}
	for a: Dictionary in aliens:
		var d := global_position.distance_to(a["pos"])
		if d < SCAN_RANGE and d < closest_dist:
			closest_dist = d
			found = a

	if found.is_empty():
		_scan_msg   = "NO ALIEN SIGNAL DETECTED"
		_scan_timer = 2.5
		return

	var id: String = found["id"]
	if id in _registered:
		_scan_msg   = id + " — ALREADY REGISTERED"
		_scan_timer = 2.5
		return

	# Scanned — defer payout to BooBies CLERK desk
	_registered.append(id)
	_scan_msg   = "SCANNED: %s · %s\nFLY TO BOOBIES — COLLECT BOUNTY  +%d ₩" % [
		id, found["species"], found["woolongs"]]
	_scan_timer = 4.0
	if has_node("/root/GameState"):
		var gs := get_node("/root/GameState")
		gs.pending_aliens.append({"id": id, "woolongs": int(found["woolongs"])})
		gs.registered_aliens = _registered.duplicate()

# ── physics ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_handle_input(delta)
	_apply_flight(delta)
	_update_engine_glow()
	_update_docking(delta)
	if _scan_timer > 0.0:
		_scan_timer -= delta
	if _objective_timer > 0.0:
		_objective_timer -= delta
		if _objective_label:
			var a: float = clampf(_objective_timer, 0.0, 1.0)
			_objective_label.add_theme_color_override("font_color", Color(CYAN.r, CYAN.g, CYAN.b, a))
			_objective_label.visible = _objective_timer > 0.0
	_update_hud()

func _handle_input(delta: float) -> void:
	if _docked or _parked: return
	if Input.is_key_pressed(KEY_W):
		throttle = move_toward(throttle,  1.0, delta * 1.8)
	elif Input.is_key_pressed(KEY_S):
		throttle = move_toward(throttle, -0.5, delta * 1.8)
	else:
		throttle = move_toward(throttle,  0.0, delta * 0.6)

	var roll := 0.0
	if Input.is_key_pressed(KEY_Q): roll =  1.0
	if Input.is_key_pressed(KEY_E): roll = -1.0
	rotate_object_local(Vector3.BACK, roll * ROT_SPEED * delta)

	if _boosting:
		_boost_timer -= delta
		if _boost_timer <= 0.0:
			_boosting       = false
			_boost_cooldown = BOOST_COOLDOWN
	if _boost_cooldown > 0.0:
		_boost_cooldown -= delta

func _apply_flight(delta: float) -> void:
	if _docked or _parked: return
	var right := global_transform.basis.x
	var up    := global_transform.basis.y
	var sx := 0.0; var sy := 0.0
	if Input.is_key_pressed(KEY_A):    sx = -1.0
	if Input.is_key_pressed(KEY_D):    sx =  1.0
	if Input.is_key_pressed(KEY_CTRL): sy = -1.0
	if Input.is_key_pressed(KEY_SHIFT):sy =  1.0

	var target_speed := throttle * _boost_speed()

	if flight_assist:
		var lv := global_transform.basis.inverse() * velocity
		lv.z = move_toward(lv.z, -target_speed, THRUST * delta)
		lv.x = move_toward(lv.x, sx * STRAFE_THRUST * 0.7, STRAFE_THRUST * delta * 2.5)
		lv.y = move_toward(lv.y, sy * STRAFE_THRUST * 0.7, STRAFE_THRUST * delta * 2.5)
		velocity = global_transform.basis * lv
	else:
		velocity += -global_transform.basis.z * throttle * THRUST * delta
		velocity += right * sx * STRAFE_THRUST * delta
		velocity += up    * sy * STRAFE_THRUST * delta
		var spd := velocity.length()
		if spd > _boost_speed() * 1.8:
			velocity = velocity.normalized() * _boost_speed() * 1.8

	# Planetary gravity — inverse-square, always on, no video game drag
	_accumulate_gravity()
	velocity += _gravity_accel * delta

	global_position += velocity * delta

func _boost_speed() -> float:
	return BOOST_SPEED if _boosting else MAX_SPEED

func _update_engine_glow() -> void:
	var e := 0.4 + absf(throttle) * 2.8 + (4.0 if _boosting else 0.0)
	if _engine_light_l: _engine_light_l.light_energy = e
	if _engine_light_r: _engine_light_r.light_energy = e

# ── HUD ────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	# ── speed bar ───────────────────────────────────────────────────────────
	var spd_bg := _hud_panel(root, PINK_DIM)
	spd_bg.anchor_left = 0.0; spd_bg.anchor_right  = 0.0
	spd_bg.anchor_top  = 0.5; spd_bg.anchor_bottom = 0.5
	spd_bg.offset_left = 28;  spd_bg.offset_right  = 50
	spd_bg.offset_top  = -85; spd_bg.offset_bottom = 85

	_speed_fill = ColorRect.new()
	_speed_fill.color    = PINK
	_speed_fill.position = Vector2(2, 2)
	_speed_fill.size     = Vector2(18, 0)
	spd_bg.add_child(_speed_fill)

	_speed_label = _hud_label(root, "0 m/s", 12, PINK)
	_speed_label.anchor_left = 0.0; _speed_label.anchor_right  = 0.0
	_speed_label.anchor_top  = 0.5; _speed_label.anchor_bottom = 0.5
	_speed_label.offset_left = 14;  _speed_label.offset_right  = 90
	_speed_label.offset_top  = 92;  _speed_label.offset_bottom = 110

	# ── throttle bar ────────────────────────────────────────────────────────
	var thr_bg := _hud_panel(root, PINK_DIM)
	thr_bg.anchor_left = 0.0; thr_bg.anchor_right  = 0.0
	thr_bg.anchor_top  = 0.5; thr_bg.anchor_bottom = 0.5
	thr_bg.offset_left = 56;  thr_bg.offset_right  = 70
	thr_bg.offset_top  = -85; thr_bg.offset_bottom = 85

	_throttle_fill = ColorRect.new()
	_throttle_fill.color    = PINK_DIM
	_throttle_fill.position = Vector2(2, 2)
	_throttle_fill.size     = Vector2(10, 0)
	thr_bg.add_child(_throttle_fill)

	# ── status row bottom-left ───────────────────────────────────────────────
	_fa_label = _hud_label(root, "FA:ON", 13, PINK_BRIGHT)
	_fa_label.anchor_left = 0.0; _fa_label.anchor_right  = 0.0
	_fa_label.anchor_top  = 1.0; _fa_label.anchor_bottom = 1.0
	_fa_label.offset_left = 28;  _fa_label.offset_right  = 130
	_fa_label.offset_top  = -110; _fa_label.offset_bottom = -88

	_boost_label = _hud_label(root, "BOOST READY", 12, PINK_DIM)
	_boost_label.anchor_left = 0.0; _boost_label.anchor_right  = 0.0
	_boost_label.anchor_top  = 1.0; _boost_label.anchor_bottom = 1.0
	_boost_label.offset_left = 28;  _boost_label.offset_right  = 220
	_boost_label.offset_top  = -88; _boost_label.offset_bottom = -66

	# ── woolong counter & registry ──────────────────────────────────────────
	_woolong_label = _hud_label(root, "0 WOOLONGS", 13, YELLOW)
	_woolong_label.anchor_left = 0.0; _woolong_label.anchor_right  = 0.0
	_woolong_label.anchor_top  = 1.0; _woolong_label.anchor_bottom = 1.0
	_woolong_label.offset_left = 28;  _woolong_label.offset_right  = 220
	_woolong_label.offset_top  = -66; _woolong_label.offset_bottom = -44

	_reg_label = _hud_label(root, "ALIENS: 0/5", 11, PINK_DIM)
	_reg_label.anchor_left = 0.0; _reg_label.anchor_right  = 0.0
	_reg_label.anchor_top  = 1.0; _reg_label.anchor_bottom = 1.0
	_reg_label.offset_left = 28;  _reg_label.offset_right  = 220
	_reg_label.offset_top  = -44; _reg_label.offset_bottom = -22

	# ── target info top-right ───────────────────────────────────────────────
	_target_label = _hud_label(root, "TARGET: BOOBIES", 12, CYAN)
	_target_label.anchor_left = 1.0; _target_label.anchor_right  = 1.0
	_target_label.anchor_top  = 0.0; _target_label.anchor_bottom = 0.0
	_target_label.offset_left = -220; _target_label.offset_right  = -24
	_target_label.offset_top  = 28;   _target_label.offset_bottom = 48
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_dist_label = _hud_label(root, "--- km", 11, PINK_DIM)
	_dist_label.anchor_left = 1.0; _dist_label.anchor_right  = 1.0
	_dist_label.anchor_top  = 0.0; _dist_label.anchor_bottom = 0.0
	_dist_label.offset_left = -220; _dist_label.offset_right  = -24
	_dist_label.offset_top  = 50;   _dist_label.offset_bottom = 68
	_dist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# ── scan result (center-left, temporary) ────────────────────────────────
	_scan_label = _hud_label(root, "", 13, CYAN)
	_scan_label.anchor_left = 0.5; _scan_label.anchor_right  = 0.5
	_scan_label.anchor_top  = 0.5; _scan_label.anchor_bottom = 0.5
	_scan_label.offset_left = -160; _scan_label.offset_right = 160
	_scan_label.offset_top  = 30;   _scan_label.offset_bottom = 100
	_scan_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ── crosshair ───────────────────────────────────────────────────────────
	var cross := _hud_label(root, "+", 18, Color(1,1,1,0.35))
	cross.anchor_left = 0.5; cross.anchor_right  = 0.5
	cross.anchor_top  = 0.5; cross.anchor_bottom = 0.5
	cross.offset_left = -12; cross.offset_right  = 12
	cross.offset_top  = -12; cross.offset_bottom = 12
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER

	# ── controls reminder (tiny, top-left) ──────────────────────────────────
	var hint := _hud_label(root, "R: SCAN   T: TARGET   V: VIEW   TAB: FA   SPACE: BOOST   L: DOCK", 9, PINK_DIM)
	hint.anchor_left = 0.0; hint.anchor_right  = 1.0
	hint.anchor_top  = 0.0; hint.anchor_bottom = 0.0
	hint.offset_left = 28;  hint.offset_right  = -28
	hint.offset_top  = 14;  hint.offset_bottom = 30

	# ── dock proximity hint ──────────────────────────────────────────────────
	_dock_hint_label = _hud_label(root, "", 14, YELLOW)
	_dock_hint_label.anchor_left = 0.5; _dock_hint_label.anchor_right  = 0.5
	_dock_hint_label.anchor_top  = 0.5; _dock_hint_label.anchor_bottom = 0.5
	_dock_hint_label.offset_left = -240; _dock_hint_label.offset_right  = 240
	_dock_hint_label.offset_top  = -130; _dock_hint_label.offset_bottom = -108
	_dock_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_hint_label.visible = false

	# ── waypoint marker (free-positioned, updated each frame) ───────────────
	_waypoint_marker = _hud_label(root, "◆", 18, CYAN)
	_waypoint_marker.visible = false

	# ── cargo readout (bottom-left, below woolong counter) ───────────────────
	_cargo_hud_label = _hud_label(root, "", 11, PINK_DIM)
	_cargo_hud_label.anchor_left = 0.0; _cargo_hud_label.anchor_right  = 0.0
	_cargo_hud_label.anchor_top  = 1.0; _cargo_hud_label.anchor_bottom = 1.0
	_cargo_hud_label.offset_left = 28;  _cargo_hud_label.offset_right  = 320
	_cargo_hud_label.offset_top  = -22; _cargo_hud_label.offset_bottom = -4

	# ── opening objective splash ─────────────────────────────────────────────
	_objective_label = _hud_label(root, "SCAN ALIENS  ·  DOCK AT BOOBIES  ·  TRADE FOR PROFIT\n           T: TARGET    R: SCAN    L: DOCK", 13, CYAN)
	_objective_label.anchor_left = 0.5;  _objective_label.anchor_right  = 0.5
	_objective_label.anchor_top  = 0.0;  _objective_label.anchor_bottom = 0.0
	_objective_label.offset_left = -320; _objective_label.offset_right  = 320
	_objective_label.offset_top  = 48;   _objective_label.offset_bottom = 96
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_hud_root = root
	_build_market_hud()

func _update_hud() -> void:
	var spd      := velocity.length()
	var spd_frac: float = clampf(spd / _boost_speed(), 0.0, 1.0)
	var thr_frac: float = clampf(throttle, 0.0, 1.0)
	var bar_h    := 162.0

	_speed_fill.size     = Vector2(18, bar_h * spd_frac)
	_speed_fill.position = Vector2(2,  bar_h * (1.0 - spd_frac) + 2)
	_throttle_fill.size     = Vector2(10, bar_h * thr_frac)
	_throttle_fill.position = Vector2(2,  bar_h * (1.0 - thr_frac) + 2)
	_throttle_fill.color    = PINK_BRIGHT if throttle > 0.7 else PINK

	_speed_label.text = "%d m/s" % int(spd)

	_fa_label.text = "FA: ON" if flight_assist else "FA: OFF"
	_fa_label.add_theme_color_override("font_color", PINK_BRIGHT if flight_assist else PINK_DIM)

	if _boosting:
		_boost_label.text = "BOOST  %.1fs" % _boost_timer
		_boost_label.add_theme_color_override("font_color", PINK_BRIGHT)
	elif _boost_cooldown > 0.0:
		_boost_label.text = "BOOST  COOLING  %.0fs" % _boost_cooldown
		_boost_label.add_theme_color_override("font_color", PINK_DIM)
	else:
		_boost_label.text = "BOOST  READY"
		_boost_label.add_theme_color_override("font_color", PINK)

	_woolong_label.text = "%d WOOLONGS" % _woolongs
	_reg_label.text     = "ALIENS: %d / %d" % [_registered.size(), 5]
	_reg_label.add_theme_color_override("font_color",
		YELLOW if _registered.size() == 5 else PINK_DIM)

	# Target info
	if _targets.size() > 0 and _target_idx < _targets.size():
		var t: Dictionary = _targets[_target_idx]
		var name: String  = t["name"]
		var tpos: Vector3 = t["pos"]
		var dist_km := global_position.distance_to(tpos) / 1000.0
		# Show ??? for unregistered aliens (except BooBies)
		var display_name := name
		if name != "BOOBIES" and name not in _registered:
			display_name = "??? ALIEN SIGNAL"
		_target_label.text = "[ " + display_name + " ]"
		_target_label.add_theme_color_override("font_color",
			YELLOW if name == "BOOBIES" else CYAN)
		if dist_km < 1.0:
			_dist_label.text = "%d m" % int(global_position.distance_to(tpos))
		else:
			_dist_label.text = "%.2f km" % dist_km

	# Scan result (fades when timer runs out)
	if _scan_timer > 0.0:
		_scan_label.text = _scan_msg
		var alpha: float = clampf(_scan_timer, 0.0, 1.0)
		_scan_label.add_theme_color_override("font_color", Color(CYAN.r, CYAN.g, CYAN.b, alpha))
	else:
		_scan_label.text = ""

	# Cargo readout
	if _cargo_hud_label:
		if _cargo.is_empty():
			_cargo_hud_label.text = "CARGO: empty  (%d ₩)" % _credits
		else:
			var parts: Array = []
			for good in _cargo.keys():
				parts.append("%s ×%d" % [good, _cargo[good]])
			_cargo_hud_label.text = "CARGO: " + "  ".join(parts) + "  (%d ₩)" % _credits

	_update_waypoint()

# ── hud helpers ────────────────────────────────────────────────────────────

func _hud_panel(parent: Control, border_col: Color) -> Control:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0, 0, 0, 0.55)
	style.border_color = border_col
	style.border_width_top    = 1; style.border_width_bottom = 1
	style.border_width_left   = 1; style.border_width_right  = 1
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	return p

func _hud_label(parent: Control, txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

# ── material / mesh helpers ────────────────────────────────────────────────

func _mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness    = rough
	m.metallic     = metal
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m    := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size           = size
	m.mesh              = mesh
	m.position          = pos
	m.material_override = mat
	parent.add_child(m)
	return m

# ── locations + docking ────────────────────────────────────────────────────

func _update_docking(_delta: float) -> void:
	if _docked: return
	_nearby_location = null
	for loc in _locations:
		if not is_instance_valid(loc): continue
		var d: float = global_position.distance_to(loc.global_position)
		if d <= loc.dock_radius:
			_nearby_location = loc
			break

	# Check for unregistered alien within scan range
	var nearby_alien: bool = false
	if has_meta("alien_data"):
		for a: Dictionary in get_meta("alien_data"):
			if a["id"] not in _registered:
				if global_position.distance_to(a["pos"]) <= SCAN_RANGE:
					nearby_alien = true
					break

	if _dock_hint_label:
		if _nearby_location != null:
			_dock_hint_label.text    = "[ L ]  DOCK AT  " + _nearby_location.loc_name
			_dock_hint_label.visible = true
		elif nearby_alien:
			_dock_hint_label.text    = "[ R ]  SCAN ALIEN SIGNAL"
			_dock_hint_label.visible = true
		else:
			_dock_hint_label.visible = false

func _dock(loc: Node3D) -> void:
	_docked          = true
	_docked_location = loc
	throttle         = 0.0
	velocity         = Vector3.ZERO
	if _dock_hint_label: _dock_hint_label.visible = false
	if _market_panel:    _market_panel.visible    = true
	_update_market_hud()
	_scan_msg   = "DOCKED AT  " + loc.get("loc_name")
	_scan_timer = 2.5
	# Sync economy to GameState and save
	if has_node("/root/GameState"):
		var gs := get_node("/root/GameState")
		gs.credits           = _credits
		gs.cargo             = _cargo.duplicate()
		gs.woolongs          = _woolongs
		gs.registered_aliens = _registered.duplicate()
		gs.snapshot_ship(self)
		gs.save_game()

func _undock() -> void:
	if _docked_location == null: return
	_scan_msg        = "DEPARTING  " + _docked_location.get("loc_name")
	_scan_timer      = 2.5
	_docked          = false
	_docked_location = null
	if _market_panel: _market_panel.visible = false

func _market_trade(idx: int, is_sell: bool) -> void:
	if _docked_location == null: return
	var goods: Array = _docked_location.market.keys()
	if idx >= goods.size(): return
	var good: String      = goods[idx]
	var entry: Dictionary = _docked_location.market[good]
	if is_sell:
		var have: int = _cargo.get(good, 0)
		if have <= 0:
			_scan_msg   = "NO  " + good.to_upper() + "  IN CARGO"
			_scan_timer = 2.0
			return
		_cargo[good] -= 1
		if _cargo[good] == 0: _cargo.erase(good)
		_credits    += entry["sell"]
		_scan_msg    = "SOLD  " + good.to_upper() + "  +" + str(entry["sell"]) + " ₩"
		_scan_timer  = 1.8
	else:
		var total: int = 0
		for v in _cargo.values(): total += v
		if total >= _cargo_max:
			_scan_msg   = "CARGO HOLD FULL"
			_scan_timer = 2.0
			return
		if _credits < entry["buy"]:
			_scan_msg   = "INSUFFICIENT CREDITS"
			_scan_timer = 2.0
			return
		_credits    -= entry["buy"]
		_cargo[good] = _cargo.get(good, 0) + 1
		_scan_msg    = "BOUGHT  " + good.to_upper() + "  -" + str(entry["buy"]) + " ₩"
		_scan_timer  = 1.8
	_update_market_hud()

# ── market HUD ─────────────────────────────────────────────────────────────

func _build_market_hud() -> void:
	_market_panel               = Panel.new()
	_market_panel.visible       = false
	_market_panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_market_panel.anchor_left   = 0.5
	_market_panel.anchor_right  = 0.5
	_market_panel.anchor_top    = 0.5
	_market_panel.anchor_bottom = 0.5
	_market_panel.offset_left   = -275
	_market_panel.offset_right  = 275
	_market_panel.offset_top    = -210
	_market_panel.offset_bottom = 210
	var style := StyleBoxFlat.new()
	style.bg_color          = Color(0.03, 0.01, 0.07, 0.93)
	style.border_color      = PINK
	style.border_width_top  = 2; style.border_width_bottom = 2
	style.border_width_left = 2; style.border_width_right  = 2
	_market_panel.add_theme_stylebox_override("panel", style)
	_hud_root.add_child(_market_panel)

	_market_title = _hud_label(_market_panel, "", 15, PINK_BRIGHT)
	_market_title.anchor_left  = 0.0; _market_title.anchor_right  = 1.0
	_market_title.anchor_top   = 0.0; _market_title.anchor_bottom = 0.0
	_market_title.offset_top   = 14;  _market_title.offset_bottom = 34
	_market_title.offset_left  = 14;  _market_title.offset_right  = -14
	_market_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_market_credits_label = _hud_label(_market_panel, "", 12, YELLOW)
	_market_credits_label.anchor_left  = 0.0; _market_credits_label.anchor_right  = 1.0
	_market_credits_label.anchor_top   = 0.0; _market_credits_label.anchor_bottom = 0.0
	_market_credits_label.offset_top   = 38;  _market_credits_label.offset_bottom = 56
	_market_credits_label.offset_left  = 14;  _market_credits_label.offset_right  = -14
	_market_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var sep := ColorRect.new()
	sep.color         = PINK_DIM
	sep.anchor_left   = 0.0; sep.anchor_right  = 1.0
	sep.anchor_top    = 0.0; sep.anchor_bottom = 0.0
	sep.offset_top    = 60;  sep.offset_bottom = 62
	sep.offset_left   = 14;  sep.offset_right  = -14
	_market_panel.add_child(sep)

	for i in 9:
		var row := _hud_label(_market_panel, "", 12, CYAN)
		row.anchor_left  = 0.0; row.anchor_right  = 1.0
		row.anchor_top   = 0.0; row.anchor_bottom = 0.0
		row.offset_top   = 68 + i * 22; row.offset_bottom = 88 + i * 22
		row.offset_left  = 18;           row.offset_right  = -18
		row.visible      = false
		_market_rows.append(row)

	var sep2 := ColorRect.new()
	sep2.color         = PINK_DIM
	sep2.anchor_left   = 0.0; sep2.anchor_right  = 1.0
	sep2.anchor_top    = 1.0; sep2.anchor_bottom = 1.0
	sep2.offset_top    = -68; sep2.offset_bottom = -66
	sep2.offset_left   = 14;  sep2.offset_right  = -14
	_market_panel.add_child(sep2)

	_market_cargo_label = _hud_label(_market_panel, "", 11, PINK_DIM)
	_market_cargo_label.anchor_left  = 0.0; _market_cargo_label.anchor_right  = 1.0
	_market_cargo_label.anchor_top   = 1.0; _market_cargo_label.anchor_bottom = 1.0
	_market_cargo_label.offset_top   = -62; _market_cargo_label.offset_bottom = -44
	_market_cargo_label.offset_left  = 14;  _market_cargo_label.offset_right  = -14
	_market_cargo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var ctrl_hint := _hud_label(_market_panel, "[1-9] BUY    [SHIFT+1-9] SELL    [L] DEPART", 10, PINK_DIM)
	ctrl_hint.anchor_left  = 0.0; ctrl_hint.anchor_right  = 1.0
	ctrl_hint.anchor_top   = 1.0; ctrl_hint.anchor_bottom = 1.0
	ctrl_hint.offset_top   = -40; ctrl_hint.offset_bottom = -22
	ctrl_hint.offset_left  = 14;  ctrl_hint.offset_right  = -14
	ctrl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _update_market_hud() -> void:
	if _docked_location == null: return
	_market_title.text         = _docked_location.get("loc_name") + "  —  " + _docked_location.get("loc_type")
	_market_credits_label.text = "Credits:  %d  ₩" % _credits
	var goods: Array = _docked_location.market.keys()
	var total_cargo: int = 0
	for v in _cargo.values(): total_cargo += v
	for i in _market_rows.size():
		if i < goods.size():
			var good: String      = goods[i]
			var entry: Dictionary = _docked_location.market[good]
			var have: int         = _cargo.get(good, 0)
			var have_str: String  = ("  (have %d)" % have) if have > 0 else ""
			_market_rows[i].text    = "[%d]  %s   BUY %d ₩  /  SELL %d ₩%s" % [
				i + 1, good.to_upper(), entry["buy"], entry["sell"], have_str]
			_market_rows[i].visible = true
		else:
			_market_rows[i].visible = false
	_market_cargo_label.text = "Cargo:  %d / %d  units" % [total_cargo, _cargo_max]

# ── waypoint marker ─────────────────────────────────────────────────────────

func _update_waypoint() -> void:
	if not _waypoint_marker: return
	if _docked or _targets.is_empty():
		_waypoint_marker.visible = false
		return

	var t: Dictionary  = _targets[_target_idx]
	var cam: Camera3D  = _cam_cockpit if not _external_view else _cam_external
	if not is_instance_valid(cam) or not cam.current:
		_waypoint_marker.visible = false
		return

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var half: Vector2    = vp_size * 0.5
	var margin: float    = 28.0

	var behind: bool    = cam.is_position_behind(t["pos"])
	var sp: Vector2     = cam.unproject_position(t["pos"])

	# When behind camera, unproject flips — mirror it around centre
	if behind:
		sp = vp_size - sp

	var on_screen: bool = (not behind
		and sp.x >= margin and sp.x <= vp_size.x - margin
		and sp.y >= margin and sp.y <= vp_size.y - margin)

	var final_pos: Vector2
	if on_screen:
		final_pos = sp
		_waypoint_marker.text = "◆"
	else:
		var dir: Vector2 = sp - half
		if dir == Vector2.ZERO: dir = Vector2(0, -1)
		var sx: float = (half.x - margin) / maxf(absf(dir.x), 0.01)
		var sy: float = (half.y - margin) / maxf(absf(dir.y), 0.01)
		final_pos = half + dir * minf(sx, sy)
		_waypoint_marker.text = "◈"   # different symbol when off-screen

	_waypoint_marker.position = final_pos - Vector2(10, 10)
	var is_boobie: bool = t["name"] == "BOOBIES"
	_waypoint_marker.add_theme_color_override("font_color",
		YELLOW if is_boobie else (PINK_BRIGHT if on_screen else CYAN))
	_waypoint_marker.visible = true

# ── gravity wells ───────────────────────────────────────────────────────────

func add_well(w: GravityWell) -> void:
	if w not in _wells:
		_wells.append(w)

func remove_well(w: GravityWell) -> void:
	_wells.erase(w)

func _accumulate_gravity() -> void:
	var total := Vector3.ZERO
	for w in _wells:
		if is_instance_valid(w):
			total += w.accel_at(global_position)
		else:
			_wells.erase(w)
	_gravity_accel = total   # zero in deep space → pure Newtonian

# ── on-foot transition ───────────────────────────────────────────────────────

func disable_cameras() -> void:
	_cam_cockpit.current  = false
	_cam_external.current = false
	_parked = true
	if _hud_root: _hud_root.visible = false

func enable_cameras() -> void:
	_parked          = false
	_docked          = false
	_docked_location = null
	if _hud_root:    _hud_root.visible    = true
	if _market_panel: _market_panel.visible = false
	_set_view(_external_view)
