class_name ProceduralBeing
extends Node3D
## ProceduralBeing — builds any creature/mecha/vehicle from a Blueprint dict.
## TREE_STRUCTURE — all geometry added as children in _build()
##
## Blueprint format:
##   {
##     "parts": [
##       { "type": "bone",   "length": 1.2, "radius": 0.12, "color": Color(...), "pos": Vector3(...), "rot": Vector3(...) },
##       { "type": "joint",  "radius": 0.18, "color": Color(...), "pos": Vector3(...) },
##       { "type": "panel",  "size": Vector3(0.4,0.6,0.1), "color": Color(...), "pos": Vector3(...), "rot": Vector3(...) },
##       { "type": "edge",   "from": Vector3(...), "to": Vector3(...), "radius": 0.04, "color": Color(...) },
##       { "type": "eye",    "radius": 0.06, "color": Color(...), "pos": Vector3(...) },
##       { "type": "thruster","radius": 0.12, "depth": 0.22, "color": Color(...), "pos": Vector3(...), "rot": Vector3(...) },
##     ]
##   }
##
## Usage:
##   var b := ProceduralBeing.build(blueprint)
##   add_child(b)
##
## Or inherit and override _get_blueprint():
##   class MyAlien extends ProceduralBeing:
##       func _get_blueprint() -> Dictionary: return { "parts": [...] }

@export var auto_build: bool = true   # build on _ready if true

func _ready() -> void:
	if auto_build:
		_build(_get_blueprint())

func _get_blueprint() -> Dictionary:
	## RETURN_VALUE — override in subclasses to define the being's shape
	return {}

# ── static factory ─────────────────────────────────────────────────────────

static func build(blueprint: Dictionary) -> ProceduralBeing:
	## TREE_STRUCTURE — creates a fully built ProceduralBeing from a blueprint dict
	var being := ProceduralBeing.new()
	being.auto_build = false
	being._build(blueprint)
	return being

# ── internal builder ────────────────────────────────────────────────────────

func _build(blueprint: Dictionary) -> void:
	## TREE_STRUCTURE — iterates parts array and dispatches to typed builders
	var parts: Array = blueprint.get("parts", [])
	for part in parts:
		var t: String = str(part.get("type", ""))
		match t:
			"bone":     _add_bone(part)
			"joint":    _add_joint(part)
			"panel":    _add_panel(part)
			"edge":     _add_edge(part)
			"eye":      _add_eye(part)
			"thruster": _add_thruster(part)

# ── part builders ──────────────────────────────────────────────────────────

func _add_bone(p: Dictionary) -> void:
	## TREE_STRUCTURE — elongated capsule limb / spine segment
	var length: float = p.get("length", 1.0)
	var radius: float = p.get("radius", 0.10)
	var color:  Color = p.get("color",  Color(0.5, 0.5, 0.5))
	var pos:    Vector3 = p.get("pos", Vector3.ZERO)
	var rot:    Vector3 = p.get("rot", Vector3.ZERO)

	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length + radius * 2.0
	mesh.radial_segments = 8
	mesh.rings           = 4
	mesh.material = _mat(color, 0.65, 0.0)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	add_child(mi)

func _add_joint(p: Dictionary) -> void:
	## TREE_STRUCTURE — sphere joint / bend connector / head node
	var radius: float = p.get("radius", 0.15)
	var color:  Color = p.get("color",  Color(0.4, 0.4, 0.5))
	var pos:    Vector3 = p.get("pos", Vector3.ZERO)

	var mesh := SphereMesh.new()
	mesh.radius          = radius
	mesh.height          = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings           = 5
	mesh.material = _mat(color, 0.55, 0.1)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)

func _add_panel(p: Dictionary) -> void:
	## TREE_STRUCTURE — flat armour plate / hull panel / corner block
	var size: Vector3  = p.get("size",  Vector3(0.5, 0.5, 0.08))
	var color: Color   = p.get("color", Color(0.3, 0.32, 0.38))
	var pos:   Vector3 = p.get("pos",   Vector3.ZERO)
	var rot:   Vector3 = p.get("rot",   Vector3.ZERO)

	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _mat(color, 0.80, 0.3)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	add_child(mi)

func _add_edge(p: Dictionary) -> void:
	## TREE_STRUCTURE — thin cylinder connecting two points (skeleton edge / wire)
	var from:   Vector3 = p.get("from",   Vector3.ZERO)
	var to:     Vector3 = p.get("to",     Vector3(0, 1, 0))
	var radius: float   = p.get("radius", 0.03)
	var color:  Color   = p.get("color",  Color(0.6, 0.6, 0.7))

	var diff   := to - from
	var length := diff.length()
	if length < 0.001: return

	var mesh := CylinderMesh.new()
	mesh.top_radius    = radius
	mesh.bottom_radius = radius
	mesh.height        = length
	mesh.radial_segments = 6
	mesh.material = _mat(color, 0.5, 0.2)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	# Position at midpoint, rotate to align with diff vector
	mi.position = (from + to) * 0.5
	var up := Vector3.UP
	var axis := up.cross(diff.normalized())
	if axis.length_squared() > 0.001:
		var angle := up.angle_to(diff.normalized())
		mi.transform.basis = Basis(axis.normalized(), angle)
	add_child(mi)

func _add_eye(p: Dictionary) -> void:
	## TREE_STRUCTURE — emissive eye sphere with glow
	var radius: float = p.get("radius", 0.055)
	var color:  Color = p.get("color",  Color(1.0, 0.8, 0.2))
	var pos:    Vector3 = p.get("pos", Vector3.ZERO)

	var mesh := SphereMesh.new()
	mesh.radius          = radius
	mesh.height          = radius * 2.0
	mesh.radial_segments = 6
	mesh.rings           = 4

	var mat := StandardMaterial3D.new()
	mat.albedo_color              = color.lightened(0.3)
	mat.emission_enabled          = true
	mat.emission                  = color
	mat.emission_energy_multiplier = 3.5
	mesh.material = mat

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)

func _add_thruster(p: Dictionary) -> void:
	## TREE_STRUCTURE — engine bell (hollow cylinder + emissive inner glow)
	var radius: float = p.get("radius", 0.12)
	var depth:  float = p.get("depth",  0.20)
	var color:  Color = p.get("color",  Color(0.7, 0.3, 0.1))
	var pos:    Vector3 = p.get("pos", Vector3.ZERO)
	var rot:    Vector3 = p.get("rot", Vector3.ZERO)

	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = rot

	# Bell outer shell
	var bell := CylinderMesh.new()
	bell.top_radius    = radius * 0.65
	bell.bottom_radius = radius
	bell.height        = depth
	bell.radial_segments = 10
	bell.material = _mat(color.darkened(0.3), 0.7, 0.5)
	var bell_mi := MeshInstance3D.new()
	bell_mi.mesh = bell
	root.add_child(bell_mi)

	# Inner glow disc
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color              = color.lightened(0.4)
	glow_mat.emission_enabled          = true
	glow_mat.emission                  = color
	glow_mat.emission_energy_multiplier = 4.0
	glow_mat.transparency              = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_color.a            = 0.6
	var disc := SphereMesh.new()
	disc.radius = radius * 0.5
	disc.height = radius * 0.15
	disc.radial_segments = 8
	disc.rings = 3
	disc.material = glow_mat
	var disc_mi := MeshInstance3D.new()
	disc_mi.mesh = disc
	disc_mi.position = Vector3(0, -depth * 0.5, 0)
	root.add_child(disc_mi)

	add_child(root)

# ── material helper ────────────────────────────────────────────────────────

func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	## RETURN_VALUE — quick StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = roughness
	m.metallic     = metallic
	return m
