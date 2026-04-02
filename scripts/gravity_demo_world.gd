extends Node3D
# Gravity demo: a small planetoid, a station above it, a cargo crate.
# Walk all the way around the planetoid. Enter the station, pick up the crate.
#
# HOW GRAVITY WORKS IN THIS SCENE — read before adding objects
# ─────────────────────────────────────────────────────────────
# GravityWell is an Area3D. When a PlayerBody or GravityBody enters its sphere,
# it calls add_well(self). The body then accumulates acceleration from all active
# wells each frame. Bodies can be under multiple wells simultaneously — the vector
# sum is the effective gravity. This is correct physics.
#
# PLANETOID: well at origin, radius=60, influence=540m. Always active for player.
# STATION:   well density=6000, radius=8 → grav_param≈51 → ~0.07 m/s² at 28m.
#            This is intentionally tiny. The station sits directly above the planet
#            pole (world +Y), so the planetoid's 3+ m/s² already pulls the player
#            toward the station floor. The station well exists for correctness, not
#            to provide meaningful lift. If you move the station off-axis, you must
#            override well.grav_param manually (see platform_ship.gd for how).
# PLATFORM SHIP: overrides well.grav_param = 8*18*18 = 2592. This gives ~10 m/s²
#            at 16m distance (deck surface). The ship sits at an angle on the
#            planet surface — its well provides the floor gravity that aligns with
#            the deck, overriding the planetoid's pull direction near the ship.
#
# RULE: any structure not coaxial with the planetoid (not directly above/below pole)
# needs its own well with grav_param strong enough to dominate the planetoid's pull
# at floor level. Use: grav_param = desired_g * distance_to_well_from_floor²

const GravWell      = preload("res://scripts/gravity_well.gd")
const GravBody      = preload("res://scripts/gravity_body.gd")
const PlayerClass   = preload("res://scripts/player_body.gd")
const PlatformShip  = preload("res://scripts/platform_ship.gd")

const PLANETOID_RADIUS := 60.0
const STATION_DIST     := 160.0   # above planetoid surface

var _star_root: Node3D
var _player: Node3D
var _ship_surface_pos: Vector3 = Vector3.ZERO   # set in _build_ship(), used for G-key boarding

func _ready() -> void:
	_build_environment()
	_build_stars()
	_build_planetoid()
	_build_station()
	_build_ship()
	_build_crate()
	_build_player()

func _process(_delta: float) -> void:
	if _star_root and _player:
		_star_root.global_position = _player.global_position

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if (event as InputEventKey).keycode != KEY_G: return
	if not is_instance_valid(_player): return
	if _ship_surface_pos == Vector3.ZERO: return
	if _player.global_position.distance_to(_ship_surface_pos) > 22.0: return
	# Board the platform ship — return to main space scene
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# ── environment ────────────────────────────────────────────────────────────

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode    = Environment.BG_COLOR
	env.background_color   = Color(0.004, 0.004, 0.014, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.55, 0.58, 0.72)   # cool-white fill, not pitch-black shadows
	env.ambient_light_energy = 1.4
	env.glow_enabled   = false   # glow looks pretty but eats contrast and visibility
	env.fog_enabled    = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Main sun — strong enough to read surface detail
	var sun := DirectionalLight3D.new()
	sun.light_energy       = 2.2
	sun.light_color        = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled     = true
	sun.rotation_degrees   = Vector3(-35, 22, 0)
	add_child(sun)

	# Weak fill light from opposite side so shadow faces aren't black
	var fill := DirectionalLight3D.new()
	fill.light_energy     = 0.35
	fill.light_color      = Color(0.55, 0.65, 0.9)
	fill.shadow_enabled   = false
	fill.rotation_degrees = Vector3(20, -140, 0)
	add_child(fill)

func _build_stars() -> void:
	_star_root = Node3D.new()
	add_child(_star_root)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	mesh.radial_segments = 4
	mesh.rings = 2

	var mat := StandardMaterial3D.new()
	mat.shading_mode          = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled      = true
	mat.emission              = Color(1.0, 0.94, 0.82)
	mat.emission_energy_multiplier = 4.0
	mat.billboard_mode        = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale  = true
	mesh.surface_set_material(0, mat)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count   = 2000
	mm.mesh             = mesh

	for i in 2000:
		var theta := rng.randf() * TAU
		var phi   := acos(rng.randf_range(-1.0, 1.0))
		var r     := rng.randf_range(800.0, 1200.0)
		var pos   := Vector3(sin(phi)*cos(theta)*r, sin(phi)*sin(theta)*r, cos(phi)*r)
		var s: float = clamp(r * 0.00022 * rng.randf_range(0.5, 1.8), 0.2, 1.4)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s,s,s)), pos))

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	_star_root.add_child(mmi)

# ── planetoid ──────────────────────────────────────────────────────────────

func _build_planetoid() -> void:
	# Visual sphere
	var planet := MeshInstance3D.new()
	var pmesh  := SphereMesh.new()
	pmesh.radius         = PLANETOID_RADIUS
	pmesh.height         = PLANETOID_RADIUS * 2.0
	pmesh.radial_segments = 48
	pmesh.rings          = 24
	planet.mesh = pmesh

	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.38, 0.30, 0.22)
	pmat.roughness    = 0.95
	pmat.metallic     = 0.0
	planet.material_override = pmat
	add_child(planet)

	# Collision
	var body    := StaticBody3D.new()
	var col     := CollisionShape3D.new()
	var sphere  := SphereShape3D.new()
	sphere.radius = PLANETOID_RADIUS
	col.shape = sphere
	body.add_child(col)
	add_child(body)

	# Gravity well — rocky planetoid, surface gravity ~5 m/s²
	var well := GravWell.new()
	well.density         = 3200.0
	well.radius          = 60.0
	well.influence_scale = 9.0
	add_child(well)   # at origin — same as planetoid center

	# A few surface rocks for visual texture
	for i in 8:
		var angle := float(i) / 8.0 * TAU + 0.3
		var up    := Vector3(sin(angle * 0.7), cos(angle), sin(angle * 1.3)).normalized()
		_rock(up * (PLANETOID_RADIUS + 1.5), up)

func _rock(pos: Vector3, up: Vector3) -> void:
	var r  := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(randf_range(2,5), randf_range(1,3), randf_range(2,4))
	r.mesh  = bm
	r.position = pos
	# Orient rock so its local up faces outward from planet
	var fwd := up.cross(Vector3.RIGHT)
	if fwd.length_squared() < 0.01: fwd = up.cross(Vector3.FORWARD)
	fwd = fwd.normalized()
	r.transform.basis = Basis(fwd.cross(up).normalized(), up, -fwd)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.24, 0.18)
	mat.roughness    = 1.0
	r.material_override = mat
	add_child(r)

# ── station ────────────────────────────────────────────────────────────────

func _build_station() -> void:
	var spos := Vector3(0, PLANETOID_RADIUS + STATION_DIST, 0)

	var station := Node3D.new()
	station.position = spos
	add_child(station)

	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color  = Color(0.18, 0.18, 0.24)
	hull_mat.roughness     = 0.7
	hull_mat.metallic      = 0.5
	hull_mat.emission_enabled = true
	hull_mat.emission      = Color(0.05, 0.06, 0.14)
	hull_mat.emission_energy_multiplier = 0.2

	# Room: floor, ceiling, 4 walls — leave south wall open as entrance
	_panel(station, Vector3(12, 0.4, 10),  Vector3(0, -3,  0), hull_mat)   # floor
	_panel(station, Vector3(12, 0.4, 10),  Vector3(0,  4,  0), hull_mat)   # ceiling
	_panel(station, Vector3(0.4,  8, 10),  Vector3(-6, 0.5, 0), hull_mat) # left
	_panel(station, Vector3(0.4,  8, 10),  Vector3( 6, 0.5, 0), hull_mat) # right
	_panel(station, Vector3(12,   8, 0.4), Vector3(0, 0.5, -5), hull_mat) # back

	# Interior lights — bright enough to actually see the room
	for lp: Vector3 in [Vector3(-4, 3, -3), Vector3(4, 3, -3), Vector3(0, 3, 2)]:
		var l := OmniLight3D.new()
		l.position       = lp
		l.light_color    = Color(0.9, 0.92, 1.0)
		l.light_energy   = 2.5
		l.omni_range     = 14.0
		station.add_child(l)

	# Station gravity well — dense anchor below floor, pulls toward station floor
	var well := GravWell.new()
	well.density         = 6000.0
	well.radius          = 8.0
	well.influence_scale = 4.0
	well.position        = Vector3(0, -30, 0)   # below floor
	station.add_child(well)

	# Running lights
	for lp: Vector3 in [Vector3(6,4,5), Vector3(-6,4,5), Vector3(6,4,-5), Vector3(-6,4,-5)]:
		var l := OmniLight3D.new()
		l.position     = lp
		l.light_color  = Color(0.3, 0.7, 1.0)
		l.light_energy = 1.2
		l.omni_range   = 12.0
		station.add_child(l)

func _panel(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var m    := MeshInstance3D.new()
	var bm   := BoxMesh.new()
	bm.size  = size
	m.mesh   = bm
	m.position = pos
	m.material_override = mat
	# Collision for walking on
	var body := StaticBody3D.new()
	var col  := CollisionShape3D.new()
	var box  := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	parent.add_child(body)
	body.add_child(col)
	parent.add_child(m)

# ── platform ship ──────────────────────────────────────────────────────────

func _build_ship() -> void:
	var ship := PlatformShip.new()
	# Park it on the planet surface, rotated 90° so the engines face away from the player spawn
	# Surface at +X side of planet: position along X axis
	var surface_normal := Vector3(1, 0.4, 0).normalized()
	ship.position = surface_normal * (PLANETOID_RADIUS + 1.5)
	_ship_surface_pos = ship.position   # save for G-key boarding check
	# Orient so deck faces away from planet center (up = surface_normal)
	var fwd := surface_normal.cross(Vector3.FORWARD).normalized()
	if fwd.length_squared() < 0.01: fwd = surface_normal.cross(Vector3.RIGHT).normalized()
	var rgt := fwd.cross(surface_normal).normalized()
	ship.transform.basis = Basis(rgt, surface_normal, -fwd)
	add_child(ship)

# ── cargo crate ────────────────────────────────────────────────────────────

func _build_crate() -> void:
	var crate := GravBody.new()
	crate.density      = 800.0   # light cargo, mass auto-calculated ≈ 214 kg-equiv
	crate.shape_radius = 0.4

	var mesh := MeshInstance3D.new()
	var bm   := BoxMesh.new()
	bm.size  = Vector3(0.8, 0.8, 0.8)
	mesh.mesh = bm
	var mat  := StandardMaterial3D.new()
	mat.albedo_color  = Color(0.55, 0.38, 0.18)
	mat.roughness     = 0.9
	mat.emission_enabled = true
	mat.emission      = Color(0.3, 0.2, 0.05)
	mat.emission_energy_multiplier = 0.2
	mesh.material_override = mat

	var col  := CollisionShape3D.new()
	var box  := BoxShape3D.new()
	box.size = Vector3(0.8, 0.8, 0.8)
	col.shape = box

	crate.add_child(mesh)
	crate.add_child(col)
	# Spawn inside station
	crate.position = Vector3(2, -2.2, -2) + Vector3(0, PLANETOID_RADIUS + STATION_DIST, 0)
	add_child(crate)

# ── player ─────────────────────────────────────────────────────────────────

func _build_player() -> void:
	var player := PlayerClass.new()

	var col   := CollisionShape3D.new()
	var cap   := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	col.shape  = cap
	player.add_child(col)

	# Spawn on planetoid surface — 2 units above it, gravity will settle the rest
	player.position = Vector3(0, PLANETOID_RADIUS + 2.0, 0)
	add_child(player)
	_player = player
