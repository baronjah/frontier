extends Node3D
# FRONTIER × SPACE DANDY
# He's a dandy guy in space. Register undiscovered aliens, collect woolongs.
# Head to BooBies between hunts. Try not to get killed by the Gogol Empire.

# ── alien manifest ─────────────────────────────────────────────────────────
# Every registered alien pays woolongs at the Alien Registration Center (inside BooBies).
# Scan range: 500m — you have to actually fly close to find them.

const ALIEN_DATA: Array[Dictionary] = [
	{"id":"MEOW",    "species":"Betelgeusian",  "type":"CAT-TYPE",     "woolongs":350,  "pos":Vector3(  820,  110, -1850)},
	{"id":"FLORA",   "species":"Plantian",      "type":"FLORA-TYPE",   "woolongs":550,  "pos":Vector3( -550,  -90, -3100)},
	{"id":"TINK-47", "species":"Robonoid",      "type":"MECH-TYPE",    "woolongs":1200, "pos":Vector3( 2150,  280, -1100)},
	{"id":"BROTCH",  "species":"Gogol Empire",  "type":"PATROL-TYPE",  "woolongs":2500, "pos":Vector3(-1750,  180,  -750)},
	{"id":"DR. GEL", "species":"Unknown",       "type":"RARE-TYPE",    "woolongs":8000, "pos":Vector3( 3600, -380, -4200)},
]

const BOOBIE_POS := Vector3(900, 80, -2200)

var _ship: Node3D
var _star_root: Node3D
var _boobie_ring: Node3D   # the spinning outer ring
var _locations: Array    = []
var _planet_wells: Array = []
var _player: Node3D      = null

func _ready() -> void:
	_build_environment()
	_build_stars()
	_build_sun()
	_build_planets()
	_build_boobie_station()
	_build_aliens()
	_build_locations()
	_build_ship()
	_build_planet_gravity()
	_build_planet_rings()
	_build_asteroid_belt()
	# Ship is a plain Node3D — Area3D signals don't fire for it.
	# Register planet wells manually so it feels orbital gravity.
	for w in _planet_wells:
		_ship.call("add_well", w)
	# Wire ship reference to all alien NPCs so they can track/flee
	for alien_node in get_tree().get_nodes_in_group("alien"):
		if alien_node.has_method("set_ship"):
			alien_node.call("set_ship", _ship)
	# Wire planet LOD observer to the ship so LOD updates as ship moves
	if _planet_betelgeuse: _planet_betelgeuse.set_observer(_ship)
	if _planet_x:          _planet_x.set_observer(_ship)

func _process(delta: float) -> void:
	if is_instance_valid(_ship) and is_instance_valid(_star_root):
		_star_root.global_position = _ship.global_position
	if is_instance_valid(_boobie_ring):
		_boobie_ring.rotation.y += delta * 0.20

# ── environment ────────────────────────────────────────────────────────────

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = Color(0.004, 0.002, 0.014, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.20, 0.06, 0.28)   # purple ambient — space dandy palette
	env.ambient_light_energy = 0.5
	env.glow_enabled   = true
	env.glow_intensity = 1.2
	env.glow_bloom     = 0.5
	env.fog_enabled    = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun_dir := DirectionalLight3D.new()
	sun_dir.light_energy     = 2.2
	sun_dir.light_color      = Color(1.0, 0.90, 0.78)
	sun_dir.shadow_enabled   = true
	sun_dir.rotation_degrees = Vector3(-18, 28, 0)
	add_child(sun_dir)

# ── stars ──────────────────────────────────────────────────────────────────

func _build_stars() -> void:
	_star_root = Node3D.new()
	add_child(_star_root)

	var rng := RandomNumberGenerator.new()
	rng.seed = 314159

	var mesh := SphereMesh.new()
	mesh.radius = 0.26
	mesh.height = 0.52
	mesh.radial_segments = 4
	mesh.rings = 2

	var mat := StandardMaterial3D.new()
	mat.shading_mode            = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled        = true
	mat.emission                = Color.WHITE
	mat.emission_energy_multiplier = 5.0
	mat.billboard_mode          = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale    = true
	mesh.surface_set_material(0, mat)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors       = true
	mm.instance_count   = 6000
	mm.mesh             = mesh

	# Space Dandy palette — pinks and purples mixed into the standard star colors
	var palettes := [
		Color(0.70, 0.82, 1.00),   # blue-white
		Color(1.00, 1.00, 1.00),   # white
		Color(1.00, 0.88, 0.65),   # warm yellow
		Color(1.00, 0.55, 0.85),   # hot pink
		Color(0.80, 0.55, 1.00),   # purple
		Color(0.50, 0.95, 0.90),   # cyan-teal
	]

	for i in 6000:
		var theta := rng.randf() * TAU
		var phi   := acos(rng.randf_range(-1.0, 1.0))
		var r     := rng.randf_range(2400.0, 3800.0)
		var pos   := Vector3(sin(phi)*cos(theta)*r, sin(phi)*sin(theta)*r, cos(phi)*r)
		var s: float = clampf(r * 0.00016 * rng.randf_range(0.5, 2.0), 0.15, 1.8)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s,s,s)), pos))
		mm.set_instance_color(i, palettes[rng.randi() % palettes.size()])

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	_star_root.add_child(mmi)

# ── sun ────────────────────────────────────────────────────────────────────

func _build_sun() -> void:
	var sun_pos := Vector3(12000, 3000, -22000)

	var sun := _sphere_mi(sun_pos, 700.0)
	var smat := StandardMaterial3D.new()
	smat.albedo_color              = Color(1.0, 0.88, 0.55)
	smat.emission_enabled          = true
	smat.emission                  = Color(1.0, 0.62, 0.12)
	smat.emission_energy_multiplier= 7.0
	smat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun.material_override = smat
	add_child(sun)

	var corona := _sphere_mi(sun_pos, 840.0)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color              = Color(1.0, 0.40, 0.08, 0.09)
	cmat.emission_enabled          = true
	cmat.emission                  = Color(1.0, 0.32, 0.05)
	cmat.emission_energy_multiplier= 0.9
	cmat.transparency              = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.cull_mode                 = BaseMaterial3D.CULL_DISABLED
	cmat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	corona.material_override = cmat
	add_child(corona)

# ── planets ────────────────────────────────────────────────────────────────

var _planet_betelgeuse: PlanetLOD = null
var _planet_x: PlanetLOD = null

func _build_planets() -> void:
	# Planet Betelgeuse — tropical ocean world, vivid teal
	_planet_betelgeuse               = PlanetLOD.new()
	_planet_betelgeuse.radius        = 800.0
	_planet_betelgeuse.surface_color = Color(0.18, 0.62, 0.55)
	_planet_betelgeuse.ocean_color   = Color(0.06, 0.35, 0.62)
	_planet_betelgeuse.name_label    = "BETELGEUSE"
	_planet_betelgeuse.position      = Vector3(600, -300, -6500)
	add_child(_planet_betelgeuse)

	# Planet X — alien gas giant, deep magenta swirls
	_planet_x               = PlanetLOD.new()
	_planet_x.radius        = 680.0
	_planet_x.surface_color = Color(0.58, 0.18, 0.42)
	_planet_x.ocean_color   = Color(0.58, 0.18, 0.42)   # gas giant — same color
	_planet_x.name_label    = "PLANET X"
	_planet_x.position      = Vector3(-3500, 800, -9000)
	add_child(_planet_x)

# ── planet rings ───────────────────────────────────────────────────────────

func _build_planet_rings() -> void:
	## TREE_STRUCTURE — adds Planet X ring disc as tilted cylinder
	var ring_node := Node3D.new()
	ring_node.position  = Vector3(-3500, 800, -9000)   # same as Planet X
	ring_node.rotation.z = deg_to_rad(28.0)
	add_child(ring_node)
	var ring_mi  := MeshInstance3D.new()
	var ring_cyl := CylinderMesh.new()
	ring_cyl.top_radius      = 900.0
	ring_cyl.bottom_radius   = 900.0
	ring_cyl.height          = 18.0
	ring_cyl.radial_segments = 48
	ring_mi.mesh = ring_cyl
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color               = Color(0.55, 0.35, 0.22, 0.45)
	rmat.emission_enabled           = true
	rmat.emission                   = Color(0.38, 0.18, 0.08)
	rmat.emission_energy_multiplier = 0.35
	rmat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.cull_mode                  = BaseMaterial3D.CULL_DISABLED
	rmat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mi.material_override = rmat
	ring_node.add_child(ring_mi)

# ── BooBies restaurant & alien registration center ────────────────────────

func _build_boobie_station() -> void:
	var root := Node3D.new()
	root.position = BOOBIE_POS
	add_child(root)

	# Hull dark metal
	var hull_mat := _mat(Color(0.14, 0.08, 0.14), 0.65, 0.75)

	# Main disc body — the diner floor deck
	_cyl(root, 78.0, 32.0, hull_mat)

	# Under-belly (machinery, slightly darker)
	var belly := _cyl_mi(0.0, -22.0, 0.0, 65.0, 14.0)
	belly.material_override = _mat(Color(0.10, 0.06, 0.10), 0.80, 0.60)
	root.add_child(belly)

	# Upper dome (the diner interior visible from above)
	var dome_mi := _sphere_mi(Vector3(0, 24, 0), 55.0, 24, 12)
	var dome_mat := StandardMaterial3D.new()
	dome_mat.albedo_color              = Color(0.12, 0.06, 0.12)
	dome_mat.roughness                 = 0.55
	dome_mat.metallic                  = 0.80
	dome_mat.emission_enabled          = true
	dome_mat.emission                  = Color(0.85, 0.05, 0.40)
	dome_mat.emission_energy_multiplier= 0.28
	dome_mi.material_override = dome_mat
	root.add_child(dome_mi)

	# BooBies sign — big hot-pink neon panel
	var sign := MeshInstance3D.new()
	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(80, 22, 6)
	sign.mesh = sign_mesh
	sign.position = Vector3(0, 70, 0)
	var sign_mat := StandardMaterial3D.new()
	sign_mat.albedo_color              = Color(1.0, 0.02, 0.42)
	sign_mat.emission_enabled          = true
	sign_mat.emission                  = Color(1.0, 0.02, 0.42)
	sign_mat.emission_energy_multiplier= 6.0
	sign_mat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	sign.material_override = sign_mat
	root.add_child(sign)

	# "REGISTER HERE" sub-sign — yellow
	var sub := MeshInstance3D.new()
	var sub_mesh := BoxMesh.new()
	sub_mesh.size = Vector3(58, 10, 5)
	sub.mesh = sub_mesh
	sub.position = Vector3(0, 54, 0)
	var sub_mat := StandardMaterial3D.new()
	sub_mat.albedo_color              = Color(1.0, 0.72, 0.0)
	sub_mat.emission_enabled          = true
	sub_mat.emission                  = Color(1.0, 0.72, 0.0)
	sub_mat.emission_energy_multiplier= 3.5
	sub_mat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	sub.material_override = sub_mat
	root.add_child(sub)

	# Docking approach arm — extends out front
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(8, 6, 55)
	arm.mesh = arm_mesh
	arm.position = Vector3(0, -12, -105)
	arm.material_override = hull_mat
	root.add_child(arm)

	# Docking slot glow (green, like Elite)
	var slot_mat := StandardMaterial3D.new()
	slot_mat.albedo_color              = Color(0, 0, 0)
	slot_mat.emission_enabled          = true
	slot_mat.emission                  = Color(0.1, 1.0, 0.3)
	slot_mat.emission_energy_multiplier= 1.2
	slot_mat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	var slot := MeshInstance3D.new()
	var slot_mesh := BoxMesh.new()
	slot_mesh.size = Vector3(22, 8, 3)
	slot.mesh = slot_mesh
	slot.position = Vector3(0, -12, -132)
	slot.material_override = slot_mat
	root.add_child(slot)

	# Porthole windows — emissive dots around the disc equator
	var win_mat := StandardMaterial3D.new()
	win_mat.albedo_color              = Color(1.0, 0.82, 0.55)
	win_mat.emission_enabled          = true
	win_mat.emission                  = Color(1.0, 0.82, 0.55)
	win_mat.emission_energy_multiplier= 2.0
	win_mat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 16:
		var a := float(i) / 16.0 * TAU
		var wp := Vector3(cos(a)*76, 4, sin(a)*76)
		var w := MeshInstance3D.new()
		var wm := SphereMesh.new()
		wm.radius = 2.2
		wm.height = 4.4
		wm.radial_segments = 6
		wm.rings = 4
		w.mesh = wm
		w.material_override = win_mat
		w.position = wp
		root.add_child(w)

	# Spinning outer ring (separate node so it rotates independently)
	_boobie_ring = Node3D.new()
	_boobie_ring.position = BOOBIE_POS
	add_child(_boobie_ring)

	var ring_mi  := MeshInstance3D.new()
	var ring_cyl := CylinderMesh.new()
	ring_cyl.top_radius      = 120.0
	ring_cyl.bottom_radius   = 120.0
	ring_cyl.height          = 10.0
	ring_cyl.radial_segments = 48
	ring_mi.mesh = ring_cyl
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color              = Color(0.12, 0.05, 0.12)
	rmat.emission_enabled          = true
	rmat.emission                  = Color(1.0, 0.05, 0.50)
	rmat.emission_energy_multiplier= 1.0
	ring_mi.material_override = rmat
	_boobie_ring.add_child(ring_mi)

	# Ring beacon lights
	for i in 10:
		var a := float(i) / 10.0 * TAU
		var lp := Vector3(cos(a)*120, 0, sin(a)*120)
		var l  := OmniLight3D.new()
		l.position    = lp
		l.light_color = Color(1.0, 0.08, 0.55)
		l.light_energy= 3.0
		l.omni_range  = 50.0
		_boobie_ring.add_child(l)

	# Main BooBies flood lights
	for off: Vector3 in [Vector3(0,80,0), Vector3(0,-30,0)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.25, 0.60)
		l.light_energy= 5.0
		l.omni_range  = 200.0
		l.position    = BOOBIE_POS + off
		add_child(l)

# ── alien ships ────────────────────────────────────────────────────────────

func _build_aliens() -> void:
	for data: Dictionary in ALIEN_DATA:
		var root := Node3D.new()
		root.position  = data["pos"]
		root.set_meta("alien_data", data)
		# Attach NPC behaviour — _ready fires at add_child below, meta already set
		root.set_script(load("res://scripts/alien_npc.gd"))
		root.add_to_group("alien")
		match data["type"]:
			"CAT-TYPE":    _alien_cat(root)
			"FLORA-TYPE":  _alien_flora(root)
			"MECH-TYPE":   _alien_mech(root)
			"PATROL-TYPE": _alien_gogol(root)
			"RARE-TYPE":   _alien_rare(root)
		add_child(root)

func _alien_cat(root: Node3D) -> void:
	# Small round Betelgeusian ship — looks a bit like a cat face
	var mat := _glow_mat(Color(1.0, 0.78, 0.18), Color(0.9, 0.55, 0.05), 1.2)
	_add_box(root, Vector3(10, 7, 14), Vector3.ZERO, mat)
	_add_box(root, Vector3(8, 5, 6),   Vector3(0, 0, -8), mat)  # nose
	# Cat ears
	var ear_mat := _glow_mat(Color(0.9, 0.55, 0.12), Color(0.8, 0.30, 0.02), 0.8)
	_add_box(root, Vector3(2, 5, 2), Vector3(-4.5, 5, 4), ear_mat)
	_add_box(root, Vector3(2, 5, 2), Vector3( 4.5, 5, 4), ear_mat)
	# Engine glow dot
	var emat := _glow_mat(Color(0.5,0.2,1.0), Color(0.5,0.2,1.0), 3.0)
	_add_sphere(root, 1.8, Vector3(0, 0, 7), emat)
	var l := OmniLight3D.new()
	l.position = Vector3(0,0,8); l.light_color = Color(0.6,0.3,1.0); l.light_energy=2.0; l.omni_range=25.0
	root.add_child(l)

func _alien_flora(root: Node3D) -> void:
	# Organic Plantian ship — irregular green blob cluster
	var mat := _glow_mat(Color(0.22, 0.72, 0.28), Color(0.08, 0.45, 0.12), 0.8)
	var rng  := RandomNumberGenerator.new(); rng.seed = 999
	for i in 6:
		var sz := Vector3(rng.randf_range(6,14), rng.randf_range(5,10), rng.randf_range(8,16))
		var po := Vector3(rng.randf_range(-8,8), rng.randf_range(-4,4), rng.randf_range(-10,10))
		_add_box(root, sz, po, mat)
	# Tendril-like protrusion
	var tmat := _glow_mat(Color(0.15,0.85,0.25), Color(0.05,0.5,0.1), 1.5)
	_add_box(root, Vector3(2,2,20), Vector3(0,6,0), tmat)
	var l := OmniLight3D.new()
	l.position = Vector3(0,0,0); l.light_color = Color(0.2,1.0,0.3); l.light_energy=1.5; l.omni_range=30.0
	root.add_child(l)

func _alien_mech(root: Node3D) -> void:
	# Robonoid ship — perfectly boxy, sensor arrays, LED lights
	var mat := _mat(Color(0.62, 0.65, 0.70), 0.35, 0.95)
	_add_box(root, Vector3(18, 18, 18), Vector3.ZERO, mat)    # main cube body
	var arm_mat := _mat(Color(0.40, 0.42, 0.48), 0.4, 0.9)
	for side: float in [-1.0, 1.0]:
		_add_box(root, Vector3(10, 2, 4), Vector3(side*14, 0, 0), arm_mat)    # sensor wings
	# Blue LEDs
	var led_mat := _glow_mat(Color(0.2,0.6,1.0), Color(0.1,0.5,1.0), 4.0)
	for lp: Vector3 in [Vector3(9,9,9), Vector3(-9,9,9), Vector3(9,-9,9), Vector3(-9,-9,9)]:
		_add_sphere(root, 0.9, lp, led_mat)
	var l := OmniLight3D.new()
	l.position = Vector3(0,0,-10); l.light_color = Color(0.3,0.6,1.0); l.light_energy=2.5; l.omni_range=40.0
	root.add_child(l)

func _alien_gogol(root: Node3D) -> void:
	# Gogol Empire patrol ship — large, intimidating, dark purple
	var mat     := _glow_mat(Color(0.22, 0.08, 0.35), Color(0.35, 0.05, 0.55), 0.4)
	var acc_mat := _glow_mat(Color(0.45, 0.05, 0.70), Color(0.55, 0.02, 0.80), 1.2)
	_add_box(root, Vector3(20, 14, 60), Vector3.ZERO, mat)          # main hull
	_add_box(root, Vector3(8,  6,  40), Vector3(0, 10, 0), mat)     # upper spine
	for side: float in [-1.0, 1.0]:
		_add_box(root, Vector3(30, 5, 28), Vector3(side*25, -2, 6), mat)  # wings
		_add_box(root, Vector3(4, 4, 12),  Vector3(side*25, -2, -16), acc_mat)  # weapon pods
	# Engine glow rear
	var emat := _glow_mat(Color(0.6,0.1,0.9), Color(0.6,0.1,0.9), 5.0)
	for ep: Vector3 in [Vector3(-5,-2,30), Vector3(5,-2,30)]:
		_add_sphere(root, 2.5, ep, emat)
	var l := OmniLight3D.new()
	l.position = Vector3(0,0,35); l.light_color = Color(0.55,0.08,0.85); l.light_energy=4.0; l.omni_range=60.0
	root.add_child(l)

func _alien_rare(root: Node3D) -> void:
	# Dr. Gel — unknown rare species. Sleek, dark, unsettling.
	var mat  := _mat(Color(0.08, 0.05, 0.06), 0.20, 0.98)
	var rmat := _glow_mat(Color(0.9, 0.06, 0.12), Color(0.9, 0.04, 0.10), 3.5)
	_add_box(root, Vector3(8, 5, 35), Vector3.ZERO, mat)             # sleek fuselage
	_add_box(root, Vector3(20, 2, 18), Vector3(0, -2, 4), mat)       # delta wing
	_add_box(root, Vector3(3, 8, 8),   Vector3(0, 4, -10), mat)      # dorsal fin
	# Red trim accents
	_add_box(root, Vector3(8, 0.5, 35), Vector3(0, 2.5, 0), rmat)
	# Eerie red engine
	_add_sphere(root, 2.2, Vector3(0, 0, 18), rmat)
	var l := OmniLight3D.new()
	l.position = Vector3(0,0,20); l.light_color = Color(1.0,0.05,0.08); l.light_energy=3.0; l.omni_range=40.0
	root.add_child(l)

# ── ship ───────────────────────────────────────────────────────────────────

func _build_ship() -> void:
	_ship = Node3D.new()
	_ship.set_script(load("res://scripts/ship_controller.gd"))

	# Restore ship position from GameState if a save exists
	var spawn_pos   := Vector3(900, 80, -1880)   # default — in front of BooBies
	var spawn_basis := Basis.IDENTITY
	if has_node("/root/GameState"):
		var gs := get_node("/root/GameState")
		if gs.ship_position != Vector3.ZERO:
			spawn_pos   = gs.ship_position
			spawn_basis = gs.ship_basis

	_ship.position = spawn_pos
	# Set meta BEFORE add_child — _ready() fires during add_child, must read these then
	_ship.set_meta("alien_data",     ALIEN_DATA)
	_ship.set_meta("boobie_pos",     BOOBIE_POS)
	_ship.set_meta("location_nodes", _locations)
	add_child(_ship)
	_ship.global_transform.basis = spawn_basis

# ── locations (dockable bodies with markets) ───────────────────────────────

func _build_locations() -> void:
	_locations.clear()

	# BooBies — Alien Registration Center + diner
	var boobie_loc              := Location.new()
	boobie_loc.loc_name         = "BOOBIES"
	boobie_loc.loc_type         = "STATION"
	boobie_loc.dock_radius      = 250.0
	boobie_loc.position         = BOOBIE_POS
	boobie_loc.market           = {
		"Food & Drinks":  {"buy": 45,  "sell": 28,  "qty": 30},
		"Bio-samples":    {"buy": 340, "sell": 220, "qty": 5},
		"Rare Aliens":    {"buy": 950, "sell": 700, "qty": 3},
	}
	add_child(boobie_loc)
	_locations.append(boobie_loc)

	# Planet Betelgeuse — tropical ocean world
	var bete_loc                := Location.new()
	bete_loc.loc_name           = "BETELGEUSE"
	bete_loc.loc_type           = "PLANET"
	bete_loc.dock_radius        = 1000.0
	bete_loc.position           = Vector3(600, -300, -6500)
	bete_loc.market             = {
		"Alien Meat":   {"buy": 55,  "sell": 38,  "qty": 20},
		"Bio-samples":  {"buy": 160, "sell": 110, "qty": 10},
		"Machinery":    {"buy": 490, "sell": 380, "qty": 8},
		"Tech Parts":   {"buy": 630, "sell": 500, "qty": 5},
	}
	add_child(bete_loc)
	_locations.append(bete_loc)

	# Planet X — alien gas giant
	var px_loc                  := Location.new()
	px_loc.loc_name             = "PLANET X"
	px_loc.loc_type             = "PLANET"
	px_loc.dock_radius          = 800.0
	px_loc.position             = Vector3(-3500, 800, -9000)
	px_loc.market               = {
		"Raw Minerals":    {"buy": 70,  "sell": 48,  "qty": 25},
		"Gas Canisters":   {"buy": 90,  "sell": 62,  "qty": 20},
		"Processed Goods": {"buy": 420, "sell": 300, "qty": 8},
		"Food & Drinks":   {"buy": 210, "sell": 165, "qty": 10},
	}
	add_child(px_loc)
	_locations.append(px_loc)

# ── planet gravity & collision ─────────────────────────────────────────────

func _build_planet_gravity() -> void:
	_planet_wells.clear()

	# Betelgeuse — teal ocean world
	var pos1 := Vector3(600, -300, -6500)
	# Surface collision so the player can land and stand
	var sb1   := StaticBody3D.new()
	sb1.position = pos1
	var sc1 := CollisionShape3D.new()
	var ss1 := SphereShape3D.new()
	ss1.radius = 800.0
	sc1.shape  = ss1
	sb1.add_child(sc1)
	add_child(sb1)
	# Gravity well: surface g ≈ 10.2 m/s², influence up to 5.5 km
	var w1 := GravityWell.new()
	w1.position = pos1
	add_child(w1)
	w1.grav_param       = 6_528_000.0
	w1.influence_radius = 5500.0
	var cs1 := w1.get_child(0) as CollisionShape3D
	if cs1 and cs1.shape is SphereShape3D:
		(cs1.shape as SphereShape3D).radius = 5500.0
	_planet_wells.append(w1)

	# Planet X — gas giant
	var pos2 := Vector3(-3500, 800, -9000)
	var sb2   := StaticBody3D.new()
	sb2.position = pos2
	var sc2 := CollisionShape3D.new()
	var ss2 := SphereShape3D.new()
	ss2.radius = 680.0
	sc2.shape  = ss2
	sb2.add_child(sc2)
	add_child(sb2)
	# Gravity well: surface g ≈ 6.9 m/s², influence up to 4.5 km
	var w2 := GravityWell.new()
	w2.position = pos2
	add_child(w2)
	w2.grav_param       = 3_200_000.0
	w2.influence_radius = 4500.0
	var cs2 := w2.get_child(0) as CollisionShape3D
	if cs2 and cs2.shape is SphereShape3D:
		(cs2.shape as SphereShape3D).radius = 4500.0
	_planet_wells.append(w2)

# ── ship ↔ on-foot transition ───────────────────────────────────────────────

func request_exit_ship(ship: Node3D, location: Location) -> void:
	if _player != null: return   # already on foot

	# Always snapshot the ship before any transition
	if has_node("/root/GameState"):
		get_node("/root/GameState").snapshot_ship(ship)

	# STATION → enter interior scene instead of spawning on-foot in space
	if location.loc_type == "STATION":
		ship.call("disable_cameras")
		get_tree().change_scene_to_file("res://scenes/demo_spaceport.tscn")
		return

	var player := CharacterBody3D.new()
	player.set_script(load("res://scripts/player_body.gd"))

	# Collision capsule must exist before the node enters the physics world
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.70
	var col    := CollisionShape3D.new()
	col.shape  = cap
	player.add_child(col)

	add_child(player)

	# Place the player on the ship, lifted away from the planet so they land gently
	var away: Vector3 = (ship.global_position - location.global_position).normalized()
	player.global_position = ship.global_position + away * 6.0

	# Give player all planet gravity wells immediately (they're inside influence range)
	for w in _planet_wells:
		if is_instance_valid(w):
			player.call("add_well", w)

	ship.call("disable_cameras")
	if has_node("/root/GameState"):
		get_node("/root/GameState").snapshot_ship(ship)
	_player = player
	_set_planet_observer(_player)   # LOD updates relative to player while on-foot

func _set_planet_observer(obs: Node3D) -> void:
	## MUTATE_GLOBAL — switches all PlanetLOD observers to obs (ship or player)
	if _planet_betelgeuse: _planet_betelgeuse.set_observer(obs)
	if _planet_x:          _planet_x.set_observer(obs)

func try_enter_ship(player: Node3D) -> void:
	if not is_instance_valid(_ship): return
	if player.global_position.distance_to(_ship.global_position) > 15.0:
		return   # too far — walk closer
	_player = null
	player.queue_free()
	_ship.call("enable_cameras")
	_set_planet_observer(_ship)   # back to ship-relative LOD
	if has_node("/root/GameState"):
		get_node("/root/GameState").save_game()

# ── asteroid belt ──────────────────────────────────────────────────────────

func _build_asteroid_belt() -> void:
	## TREE_STRUCTURE — belt sits between Betelgeuse and Planet X, offset from direct line
	# Centre chosen slightly off the direct Betelgeuse→PlanetX line so it's navigable
	var belt_centre := Vector3(-1500, 200, -7700)
	var belt := AsteroidBelt.new()
	belt.call("setup", belt_centre)
	add_child(belt)

# ── helpers ────────────────────────────────────────────────────────────────

func _sphere_mi(pos: Vector3, radius: float, segs: int = 20, rings: int = 10) -> MeshInstance3D:
	var m    := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segs
	mesh.rings  = rings
	m.mesh      = mesh
	m.position  = pos
	return m

func _cyl_mi(x: float, y: float, z: float, radius: float, height: float) -> MeshInstance3D:
	var m    := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius    = radius
	mesh.bottom_radius = radius
	mesh.height        = height
	mesh.radial_segments = 32
	m.mesh     = mesh
	m.position = Vector3(x, y, z)
	return m

func _cyl(parent: Node3D, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var m := _cyl_mi(0, 0, 0, radius, height)
	m.material_override = mat
	parent.add_child(m)
	return m

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m    := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size           = size
	m.mesh              = mesh
	m.position          = pos
	m.material_override = mat
	parent.add_child(m)
	return m

func _add_sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m    := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius         = radius
	mesh.height         = radius * 2.0
	mesh.radial_segments= 8
	mesh.rings          = 5
	m.mesh              = mesh
	m.position          = pos
	m.material_override = mat
	parent.add_child(m)
	return m

func _mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness    = rough
	m.metallic     = metal
	return m

func _glow_mat(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color              = albedo
	m.emission_enabled          = true
	m.emission                  = emission
	m.emission_energy_multiplier= energy
	m.roughness                 = 0.5
	m.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED if energy > 2.0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return m
