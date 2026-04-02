extends Node3D
# A city that learned to fly.
# Flat platform base, hab blocks bolted on top, four dumb engines in the back.
# Has its own gravity well — you can walk on the deck.

const GravWell     = preload("res://scripts/gravity_well.gd")
const RippableDoor = preload("res://scripts/rippable_door.gd")

func _ready() -> void:
	_build_platform()
	_build_buildings()
	_build_engines()
	_build_details()
	_build_lighting()
	_build_gravity()
	_build_doors()

# ── platform ────────────────────────────────────────────────────────────────

func _build_platform() -> void:
	# Main deck — wide, flat, lived-on
	_hull(Vector3(26, 1.4, 46), Vector3(0,  0,    0), Color(0.22, 0.20, 0.17))
	_hull(Vector3(22, 0.7, 34), Vector3(0,  1.05, -2), Color(0.25, 0.22, 0.19))

	# Underbelly ribs — structural, bolted-on feel
	for i in 5:
		var z := -18.0 + float(i) * 9.0
		_hull(Vector3(28, 0.7, 1.0), Vector3(0, -0.9, z), Color(0.17, 0.15, 0.13))

	# Side rails so cargo doesn't drift off
	_hull(Vector3(0.9, 1.2, 48), Vector3(-13.4, 1.1, 0), Color(0.14, 0.13, 0.11))
	_hull(Vector3(0.9, 1.2, 48), Vector3( 13.4, 1.1, 0), Color(0.14, 0.13, 0.11))

	# Nose bumper
	_hull(Vector3(26, 2.0, 1.2), Vector3(0, 0.9, -23), Color(0.18, 0.16, 0.14))

# ── buildings ───────────────────────────────────────────────────────────────

func _build_buildings() -> void:
	# Command tower — front, tallest, has the big windows
	_hull(Vector3(8, 10, 7),   Vector3(0,   6.1, -15), Color(0.19, 0.19, 0.27))
	_hull(Vector3(8, 10, 7),   Vector3(0,   6.1, -15), Color(0.19, 0.19, 0.27))  # double for thickness feel
	_glow(Vector3(8.1, 1.2, 0.15), Vector3(0, 8.5, -11.45), Color(0.85, 0.92, 1.0), 1.8)
	_glow(Vector3(8.1, 1.2, 0.15), Vector3(0, 6.5, -11.45), Color(0.85, 0.92, 1.0), 1.4)
	_glow(Vector3(8.1, 1.2, 0.15), Vector3(0, 4.5, -11.45), Color(0.85, 0.92, 1.0), 1.2)

	# Left hab block — where people actually live
	_hull(Vector3(6, 6, 10),   Vector3(-8, 4.1, -6),   Color(0.21, 0.18, 0.16))
	_glow(Vector3(0.15, 0.9, 10.1), Vector3(-5.08, 5.5, -6), Color(1.0, 0.88, 0.65), 1.2)
	_glow(Vector3(0.15, 0.9, 10.1), Vector3(-5.08, 3.8, -6), Color(1.0, 0.88, 0.65), 0.9)

	# Right hab block
	_hull(Vector3(6, 6, 10),   Vector3(8,  4.1, -6),   Color(0.21, 0.18, 0.16))
	_glow(Vector3(0.15, 0.9, 10.1), Vector3(5.08, 5.5, -6), Color(1.0, 0.88, 0.65), 1.2)
	_glow(Vector3(0.15, 0.9, 10.1), Vector3(5.08, 3.8, -6), Color(1.0, 0.88, 0.65), 0.9)

	# Central connector between hab blocks
	_hull(Vector3(4, 3, 10),   Vector3(0, 2.9, -6),    Color(0.18, 0.17, 0.15))

	# Mid marketplace / open area — low ceiling, wide
	_hull(Vector3(18, 2.5, 8),  Vector3(0, 2.45, 4),   Color(0.20, 0.18, 0.16))
	_glow(Vector3(18.1, 0.4, 0.15), Vector3(0, 3.8, 0.08), Color(1.0, 0.92, 0.7), 0.8)

	# Engine room block — rear, chunky
	_hull(Vector3(20, 5, 9),   Vector3(0, 3.6, 14),    Color(0.17, 0.16, 0.14))

	# Fuel tanks strapped to sides — that goofy cylindrical bulge
	_hull(Vector3(3.5, 4, 12), Vector3(-11, 3.1, 10),  Color(0.13, 0.20, 0.13))
	_hull(Vector3(3.5, 4, 12), Vector3( 11, 3.1, 10),  Color(0.13, 0.20, 0.13))
	_hull(Vector3(0.8, 4.2, 12.2), Vector3(-12.8, 3.1, 10), Color(0.10, 0.16, 0.10))
	_hull(Vector3(0.8, 4.2, 12.2), Vector3( 12.8, 3.1, 10), Color(0.10, 0.16, 0.10))

	# Observation deck on top of command tower — flat roof, open to space
	_hull(Vector3(10, 0.4, 9),  Vector3(0, 11.3, -15), Color(0.24, 0.22, 0.20))
	# Observation deck railing
	_hull(Vector3(10, 0.9, 0.5), Vector3(0, 11.85, -19.5), Color(0.12, 0.12, 0.12))
	_hull(Vector3(0.5, 0.9, 9),  Vector3(-5.0, 11.85, -15), Color(0.12, 0.12, 0.12))
	_hull(Vector3(0.5, 0.9, 9),  Vector3( 5.0, 11.85, -15), Color(0.12, 0.12, 0.12))

# ── engines ──────────────────────────────────────────────────────────────────

func _build_engines() -> void:
	var xs: Array[float] = [-8.5, -3.0, 3.0, 8.5]
	for x: float in xs:
		# Engine housing strapped on
		_hull(Vector3(4.0, 4.2, 9),  Vector3(x, 0.8, 20),   Color(0.14, 0.13, 0.11))
		# Mounting bracket
		_hull(Vector3(4.2, 0.8, 2),  Vector3(x, 0.4, 14.5), Color(0.11, 0.10, 0.09))
		# Nozzle bell — wider, flared
		_hull(Vector3(4.8, 4.8, 2.0), Vector3(x, 0.8, 25.0), Color(0.09, 0.08, 0.07))

		# Nozzle glow — hot inner core
		_glow(Vector3(3.2, 3.2, 0.4), Vector3(x, 0.8, 25.8), Color(1.0, 0.55, 0.1), 4.0)
		# Blue exhaust bloom
		_glow(Vector3(4.4, 4.4, 0.4), Vector3(x, 0.8, 26.2), Color(0.35, 0.55, 1.0), 2.5)

		var l_hot := OmniLight3D.new()
		l_hot.position     = Vector3(x, 0.8, 26.5)
		l_hot.light_color  = Color(0.8, 0.5, 0.15)
		l_hot.light_energy = 3.5
		l_hot.omni_range   = 10.0
		add_child(l_hot)

		var l_blue := OmniLight3D.new()
		l_blue.position     = Vector3(x, 0.8, 28.0)
		l_blue.light_color  = Color(0.3, 0.5, 1.0)
		l_blue.light_energy = 2.0
		l_blue.omni_range   = 14.0
		add_child(l_blue)

# ── details ──────────────────────────────────────────────────────────────────

func _build_details() -> void:
	# Comms dish on command tower
	_hull(Vector3(3.5, 0.3, 3.5), Vector3(4.5, 11.7, -15), Color(0.45, 0.45, 0.45))
	_hull(Vector3(0.3, 2.2, 0.3), Vector3(4.5, 10.4, -15), Color(0.40, 0.40, 0.40))
	_glow(Vector3(0.5, 0.5, 0.5),  Vector3(4.5, 11.85, -15), Color(0.3, 0.8, 1.0), 3.0)

	# Small airlock bump on left side
	_hull(Vector3(3, 2.5, 3), Vector3(-13.5, 1.9, -8), Color(0.20, 0.20, 0.25))
	_glow(Vector3(0.15, 1.8, 2.8), Vector3(-12.1, 1.9, -8), Color(0.4, 0.9, 1.0), 1.5)

	# Cargo crane arm — back deck
	_hull(Vector3(0.6, 0.6, 8),  Vector3(10, 2.0, 6),  Color(0.30, 0.28, 0.24))
	_hull(Vector3(0.6, 5, 0.6),  Vector3(10, 4.5, 2),  Color(0.30, 0.28, 0.24))
	_hull(Vector3(5, 0.6, 0.6),  Vector3(7.5, 7.0, 2), Color(0.30, 0.28, 0.24))

	# Random pipes along deck
	for i in 6:
		var z: float = -16.0 + float(i) * 6.0
		_hull(Vector3(0.4, 0.4, 5.5), Vector3(-5.5, 1.8, z), Color(0.18, 0.22, 0.18))

# ── lighting ─────────────────────────────────────────────────────────────────

func _build_lighting() -> void:
	# Nav lights — red port, green starboard
	for sign: float in [-1.0, 1.0]:
		var l := OmniLight3D.new()
		l.position     = Vector3(sign * 13.5, 1.8, -22)
		l.light_color  = Color(1.0, 0.15, 0.15) if sign < 0 else Color(0.15, 1.0, 0.15)
		l.light_energy = 1.2
		l.omni_range   = 8.0
		add_child(l)
		_glow(Vector3(0.6, 0.6, 0.6), Vector3(sign * 13.5, 1.8, -22),
			Color(1.0, 0.15, 0.15) if sign < 0 else Color(0.15, 1.0, 0.15), 4.0)

	# Warm interior light spill from hab blocks
	for pos: Vector3 in [Vector3(-8, 5, -6), Vector3(8, 5, -6), Vector3(0, 8, -15)]:
		var l := OmniLight3D.new()
		l.position     = pos
		l.light_color  = Color(1.0, 0.88, 0.68)
		l.light_energy = 1.6
		l.omni_range   = 10.0
		add_child(l)

	# Engine bay work light
	var el := OmniLight3D.new()
	el.position     = Vector3(0, 5, 14)
	el.light_color  = Color(0.85, 0.90, 1.0)
	el.light_energy = 1.0
	el.omni_range   = 12.0
	add_child(el)

# ── gravity ───────────────────────────────────────────────────────────────────

func _build_gravity() -> void:
	# Pull toward the deck — influence large enough to catch jumpers
	var well := GravWell.new()
	well.grav_param       = 8.0 * 18.0 * 18.0   # g=8, virtual surface r=18
	well.influence_radius = 45.0
	well.position         = Vector3(0, -16.0, 0) # below the keel
	add_child(well)

# ── helpers ───────────────────────────────────────────────────────────────────

func _build_doors() -> void:
	# Left hab block — door on the outer face, rusted shut
	var d1 := RippableDoor.new()
	d1.size  = Vector3(2.2, 3.2, 0.28)
	d1.color = Color(0.18, 0.14, 0.11)
	d1.position = Vector3(-11.1, 3.0, -6)   # flush with left wall face
	# Door faces outward (-X), rotate 90° around Y
	d1.transform.basis = Basis(Vector3(0,0,1), Vector3(0,1,0), Vector3(-1,0,0))
	add_child(d1)

	# Engine room — heavy blast door at the rear
	var d2 := RippableDoor.new()
	d2.size  = Vector3(2.8, 3.8, 0.32)
	d2.color = Color(0.14, 0.13, 0.11)
	d2.position = Vector3(0, 3.5, 9.65)   # front face of engine room
	add_child(d2)

func _hull(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.88
	mat.metallic     = 0.25
	mi.material_override = mat

	var body := StaticBody3D.new()
	var col  := CollisionShape3D.new()
	var box  := BoxShape3D.new()
	box.size  = size
	col.shape = box
	col.position = pos
	add_child(body)
	body.add_child(col)
	add_child(mi)

func _glow(size: Vector3, pos: Vector3, color: Color, energy: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos

	var mat := StandardMaterial3D.new()
	mat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled          = true
	mat.emission                  = color
	mat.emission_energy_multiplier = energy
	mat.albedo_color              = color
	mi.material_override = mat
	add_child(mi)
