extends Node3D
class_name RippableDoor
# A door that doesn't want to open. Hold F to charge telekinesis.
# It strains, glows hot, then rips off and flies.

const GravBody = preload("res://scripts/gravity_body.gd")

var size:  Vector3 = Vector3(2.2, 3.2, 0.28)
var color: Color   = Color(0.16, 0.15, 0.13)

var _charge:  float = 0.0   # 0.0 → 1.0
var _ripped:  bool  = false
var _active:  bool  = false  # set true each frame player calls add_charge; self-resets
var _mesh:    MeshInstance3D
var _body:    StaticBody3D
var _mat:     StandardMaterial3D
var _rng      := RandomNumberGenerator.new()

const CHARGE_SPEED := 0.55   # seconds to full charge ≈ 1.8 s
const SHAKE_MAX    := 0.18

signal ripped

func _ready() -> void:
	_rng.randomize()
	_build()

func _build() -> void:
	# Frame — thin border around the door for visual context
	for strip: Array in [
		[Vector3(0.18, size.y + 0.2, 0.22), Vector3(-(size.x * 0.5 + 0.09), 0, 0)],
		[Vector3(0.18, size.y + 0.2, 0.22), Vector3( (size.x * 0.5 + 0.09), 0, 0)],
		[Vector3(size.x + 0.36, 0.18, 0.22), Vector3(0,  size.y * 0.5 + 0.09, 0)],
		[Vector3(size.x + 0.36, 0.18, 0.22), Vector3(0, -size.y * 0.5 - 0.09, 0)],
	]:
		var fi := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = strip[0] as Vector3
		fi.mesh = fb
		fi.position = strip[1] as Vector3
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.10, 0.09, 0.08)
		fm.roughness = 0.9
		fm.metallic  = 0.5
		fi.material_override = fm
		add_child(fi)

	# Door panel
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.roughness    = 0.85
	_mat.metallic     = 0.45
	_mesh.material_override = _mat
	add_child(_mesh)

	# Bolt details — visual only
	for bp: Vector3 in [
		Vector3(-0.7,  1.1, 0.15), Vector3(0.7,  1.1, 0.15),
		Vector3(-0.7,  0.0, 0.15), Vector3(0.7,  0.0, 0.15),
		Vector3(-0.7, -1.1, 0.15), Vector3(0.7, -1.1, 0.15),
	]:
		var bolt := MeshInstance3D.new()
		var bbm  := BoxMesh.new()
		bbm.size = Vector3(0.12, 0.12, 0.08)
		bolt.mesh = bbm
		bolt.position = bp
		var bm2 := StandardMaterial3D.new()
		bm2.albedo_color = Color(0.55, 0.52, 0.48)
		bm2.roughness    = 0.5
		bm2.metallic     = 0.8
		bolt.material_override = bm2
		add_child(bolt)

	# Collision
	_body = StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	_body.add_child(col)
	add_child(_body)

# Called by player each frame while holding F and looking at this door
func add_charge(delta: float) -> void:
	if _ripped: return
	_active = true
	_charge = minf(_charge + delta * CHARGE_SPEED, 1.0)
	if _charge >= 1.0:
		_do_rip()

func _physics_process(delta: float) -> void:
	if _ripped: return

	if not _active:
		# Player released F — bleed charge on our own, no player involvement needed
		_charge = maxf(_charge - delta * 0.8, 0.0)
	_active = false   # player must call add_charge again next frame to stay active

	if _charge <= 0.0:
		# Fully bled — reset all visuals so door looks normal again
		_mesh.position        = Vector3.ZERO
		_mat.emission_enabled = false
		return

	# Shake — harder as charge builds
	var s := _charge * SHAKE_MAX
	_mesh.position = Vector3(
		_rng.randf_range(-s, s),
		_rng.randf_range(-s * 0.5, s * 0.5),
		_rng.randf_range(-s * 0.3, s * 0.3)
	)
	# Glow red-hot proportional to charge
	_mat.emission_enabled           = true
	_mat.emission                   = Color(1.0, 0.25 + _charge * 0.3, 0.02)
	_mat.emission_energy_multiplier = _charge * 3.5

func _do_rip() -> void:
	if _ripped: return
	_ripped = true

	var wpos   := global_position
	var wbasis := global_transform.basis

	_body.queue_free()
	_mesh.queue_free()

	# Become a real physics object
	var door := GravBody.new()
	door.mass = 38.0

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color              = color
	mat.roughness                 = 0.85
	mat.metallic                  = 0.45
	mat.emission_enabled          = true
	mat.emission                  = Color(1.0, 0.45, 0.05)
	mat.emission_energy_multiplier = 2.5
	mi.material_override = mat

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box

	door.add_child(mi)
	door.add_child(col)

	get_tree().current_scene.add_child(door)
	door.global_position       = wpos
	door.global_transform.basis = wbasis

	# Rip outward — forward from door face + upward tumble
	var out := wbasis.z * 14.0 + Vector3(
		_rng.randf_range(-3.0, 3.0),
		_rng.randf_range( 4.0, 9.0),
		_rng.randf_range(-3.0, 3.0)
	)
	door.linear_velocity  = out
	door.angular_velocity = Vector3(
		_rng.randf_range(-4.0, 4.0),
		_rng.randf_range(-3.0, 3.0),
		_rng.randf_range(-4.0, 4.0)
	)

	ripped.emit()
	queue_free()
