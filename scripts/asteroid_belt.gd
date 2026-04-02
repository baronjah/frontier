extends Node3D
class_name AsteroidBelt
# FRONTIER — Procedural asteroid belt
# Spawned once by space_world between Betelgeuse and Planet X.
# Each asteroid: slow random rotation, optional slow drift, collision shape.
# No physics — purely visual + static collision to keep it cheap.

const ASTEROID_COUNT : int   = 120
const BELT_RADIUS    : float = 800.0    # ring spread in XZ
const BELT_WIDTH     : float = 480.0    # random scatter within ring
const BELT_HEIGHT    : float = 200.0    # vertical scatter
const MIN_SIZE       : float = 8.0
const MAX_SIZE       : float = 65.0

# Belt centre passed in by space_world
var _centre : Vector3 = Vector3.ZERO

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 271828
	_spawn_asteroids(rng)

func setup(centre: Vector3) -> void:
	## MUTATE_GLOBAL — called before add_child so centre is set before _ready
	_centre = centre

func _spawn_asteroids(rng: RandomNumberGenerator) -> void:
	## TREE_STRUCTURE — build all asteroid meshes and static colliders
	for i in ASTEROID_COUNT:
		var ring_r : float   = BELT_RADIUS + rng.randf_range(-BELT_WIDTH * 0.5, BELT_WIDTH * 0.5)
		var angle  : float   = rng.randf() * TAU
		var height : float   = rng.randf_range(-BELT_HEIGHT * 0.5, BELT_HEIGHT * 0.5)
		var pos    : Vector3 = _centre + Vector3(
			cos(angle) * ring_r,
			height,
			sin(angle) * ring_r
		)
		var size_r : float   = rng.randf_range(MIN_SIZE, MAX_SIZE)
		var rock   : Node3D  = _build_rock(rng, pos, size_r)
		add_child(rock)

func _build_rock(rng: RandomNumberGenerator, pos: Vector3, base_r: float) -> Node3D:
	## TREE_STRUCTURE — single asteroid: mesh + static body + slow rotator
	var root := Node3D.new()
	root.position = pos

	# Mesh — use CapsuleMesh squished to look lumpy
	var mesh_i := MeshInstance3D.new()
	var mesh   := SphereMesh.new()
	mesh.radius         = base_r
	mesh.height         = base_r * 2.0
	mesh.radial_segments = max(6, int(base_r * 0.4))
	mesh.rings           = max(4, int(base_r * 0.25))
	mesh_i.mesh = mesh

	# Material — grey rock, some colour variation
	var grey : float = rng.randf_range(0.22, 0.55)
	var tint_r: float = grey + rng.randf_range(-0.06, 0.12)
	var tint_g: float = grey + rng.randf_range(-0.04, 0.04)
	var tint_b: float = grey + rng.randf_range(-0.08, 0.02)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint_r, tint_g, tint_b)
	mat.roughness    = rng.randf_range(0.70, 0.95)
	mat.metallic     = rng.randf_range(0.0,  0.15)
	mesh_i.material_override = mat

	# Randomise scale so it looks like a potato, not a ball
	mesh_i.scale = Vector3(
		rng.randf_range(0.55, 1.45),
		rng.randf_range(0.40, 1.20),
		rng.randf_range(0.60, 1.50)
	)
	mesh_i.rotation = Vector3(
		rng.randf() * TAU,
		rng.randf() * TAU,
		rng.randf() * TAU
	)

	# Static collision for larger rocks only (saves physics cost on tiny ones)
	if base_r >= 20.0:
		var sb  := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = base_r * 0.85
		col.shape  = sph
		sb.add_child(col)
		root.add_child(sb)

	root.add_child(mesh_i)

	# Rotation script inline via per-node metadata — handled in _process via a child rotator
	var rotator := AsteroidRotator.new()
	rotator.spin = Vector3(
		rng.randf_range(-0.08, 0.08),
		rng.randf_range(-0.20, 0.20),
		rng.randf_range(-0.06, 0.06)
	)
	rotator.target = mesh_i
	root.add_child(rotator)

	return root


# ── per-asteroid slow rotation helper ─────────────────────────────────────

class AsteroidRotator extends Node:
	var spin   : Vector3    = Vector3.ZERO
	var target : Node3D     = null

	func _process(delta: float) -> void:
		if is_instance_valid(target):
			target.rotation += spin * delta
