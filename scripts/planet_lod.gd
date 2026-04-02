class_name PlanetLOD
extends Node3D
## PlanetLOD — distance-based level of detail for planets
## TREE_STRUCTURE — builds all LOD meshes in code, swaps by camera distance
##
## LOD levels:
##   0  d > DIST_FAR     — single pixel-bright sphere (the "grain of sand" from space)
##   1  DIST_MID..FAR    — simple sphere, surface color only
##   2  DIST_NEAR..MID   — subdivided sphere, rough terrain color variation
##   3  d < DIST_NEAR    — chunk terrain grid visible on surface (beach + grains)
##
## Usage:
##   var planet := PlanetLOD.new()
##   planet.radius        = 420.0
##   planet.surface_color = Color(0.18, 0.55, 0.62)   # teal ocean
##   planet.name_label    = "BETELGEUSE"
##   planet.position      = Vector3(600, -300, -6500)
##   add_child(planet)
##   planet.set_observer(camera_node)   # call once after add_child

const DIST_FAR  := 12000.0   # beyond this: grain of sand
const DIST_MID  :=  3000.0   # beyond this: simple sphere
const DIST_NEAR :=   800.0   # beyond this: rough terrain
# below DIST_NEAR: full chunk grid (surface detail)

const CHUNK_GRID   := 8       # 8×8 chunks visible at surface
const CHUNK_SIZE   := 60.0    # metres per terrain chunk
const GRAIN_SIZE   := 0.8     # metres — visual grain on beach

@export var radius:        float  = 60.0
@export var surface_color: Color  = Color(0.22, 0.55, 0.30)
@export var ocean_color:   Color  = Color(0.10, 0.35, 0.55)
@export var name_label:    String = ""

var _observer: Node3D = null   # camera or ship — LOD reference point
var _current_lod: int = -1

var _lod0: MeshInstance3D = null   # grain — emissive dot
var _lod1: MeshInstance3D = null   # simple sphere
var _lod2: MeshInstance3D = null   # rough sphere
var _lod3: Node3D         = null   # chunk terrain grid
var _name_lbl: Label3D    = null
var _atmo:  MeshInstance3D = null  # atmosphere halo (always visible if near enough)

func _ready() -> void:
	_build_lod0()
	_build_lod1()
	_build_lod2()
	_build_lod3()
	_build_atmosphere()
	if name_label != "":
		_build_name_label()
	_apply_lod(0)   # start at grain until observer set

func set_observer(obs: Node3D) -> void:
	_observer = obs

# ── LOD switching ──────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not is_instance_valid(_observer): return
	var dist := global_position.distance_to(_observer.global_position)
	var target := _lod_for_dist(dist)
	if target != _current_lod:
		_apply_lod(target)
	# Atmosphere visibility: show when within 3× radius
	if _atmo:
		_atmo.visible = dist < radius * 6.0

func _lod_for_dist(d: float) -> int:
	if d > DIST_FAR:  return 0
	if d > DIST_MID:  return 1
	if d > DIST_NEAR: return 2
	return 3

func _apply_lod(lod: int) -> void:
	_current_lod = lod
	if _lod0: _lod0.visible = (lod == 0)
	if _lod1: _lod1.visible = (lod == 1)
	if _lod2: _lod2.visible = (lod == 2)
	if _lod3: _lod3.visible = (lod == 3)

# ── LOD 0 — grain of sand (emissive dot) ──────────────────────────────────

func _build_lod0() -> void:
	var m   := StandardMaterial3D.new()
	m.albedo_color              = surface_color.lightened(0.3)
	m.emission_enabled          = true
	m.emission                  = surface_color
	m.emission_energy_multiplier = 8.0   # bright star-like dot in deep space
	m.roughness                 = 0.0

	var sm   := SphereMesh.new()
	sm.radius          = maxf(radius * 0.002, 1.5)   # never smaller than 1.5m
	sm.height          = sm.radius * 2.0
	sm.radial_segments = 6
	sm.rings           = 3
	sm.material        = m

	_lod0 = MeshInstance3D.new()
	_lod0.mesh = sm
	add_child(_lod0)

# ── LOD 1 — simple sphere ─────────────────────────────────────────────────

func _build_lod1() -> void:
	var m   := StandardMaterial3D.new()
	m.albedo_color = surface_color
	m.roughness    = 0.75
	m.metallic     = 0.0

	var sm   := SphereMesh.new()
	sm.radius          = radius
	sm.height          = radius * 2.0
	sm.radial_segments = 12
	sm.rings           = 8
	sm.material        = m

	_lod1 = MeshInstance3D.new()
	_lod1.mesh = sm
	add_child(_lod1)

# ── LOD 2 — rough terrain sphere ──────────────────────────────────────────

func _build_lod2() -> void:
	# Higher-poly sphere with vertex-colored terrain variation
	var sm   := SphereMesh.new()
	sm.radius          = radius
	sm.height          = radius * 2.0
	sm.radial_segments = 32
	sm.rings           = 20

	var m := StandardMaterial3D.new()
	m.albedo_color = surface_color
	m.roughness    = 0.85
	m.metallic     = 0.0
	sm.material    = m

	_lod2 = MeshInstance3D.new()
	_lod2.mesh = sm
	add_child(_lod2)

	# Dark ocean overlay sphere (slightly smaller, transparent)
	if ocean_color != surface_color:
		var osm := SphereMesh.new()
		osm.radius          = radius * 0.994
		osm.height          = radius * 2.0 * 0.994
		osm.radial_segments = 24
		osm.rings           = 16
		var om := StandardMaterial3D.new()
		om.albedo_color  = Color(ocean_color.r, ocean_color.g, ocean_color.b, 0.6)
		om.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
		om.roughness     = 0.15
		om.metallic      = 0.1
		osm.material     = om
		var omi := MeshInstance3D.new()
		omi.mesh = osm
		_lod2.add_child(omi)

# ── LOD 3 — surface chunk grid ────────────────────────────────────────────

func _build_lod3() -> void:
	_lod3 = Node3D.new()
	_lod3.name = "ChunkGrid"
	add_child(_lod3)

	# Build a flat grid of terrain chunks tangent to the sphere top (+Y pole)
	# When camera is close enough (< DIST_NEAR), this grid is shown instead of the sphere
	# The grid is positioned at the surface (y = radius) — observer approaches from +Y

	var rng := RandomNumberGenerator.new()
	rng.seed = int(radius * 100 + surface_color.r * 255)

	var half := int(CHUNK_GRID / 2)
	for cx in range(-half, half):
		for cz in range(-half, half):
			_build_chunk(_lod3, cx, cz, rng)

	# Also show the sphere base underneath (so it looks like it continues below horizon)
	var base_m := StandardMaterial3D.new()
	base_m.albedo_color = surface_color.darkened(0.2)
	base_m.roughness    = 0.9
	var base_sm := SphereMesh.new()
	base_sm.radius          = radius * 0.98
	base_sm.height          = radius * 2.0 * 0.98
	base_sm.radial_segments = 20
	base_sm.rings           = 14
	base_sm.material        = base_m
	var base_mi := MeshInstance3D.new()
	base_mi.mesh = base_sm
	_lod3.add_child(base_mi)

func _build_chunk(parent: Node3D, cx: int, cz: int, rng: RandomNumberGenerator) -> void:
	var chunk := Node3D.new()
	# Offset from surface pole
	chunk.position = Vector3(cx * CHUNK_SIZE, radius, cz * CHUNK_SIZE)
	parent.add_child(chunk)

	# Base terrain tile
	var tile_m := StandardMaterial3D.new()
	var sand   := surface_color.lerp(Color(0.76, 0.68, 0.52), rng.randf_range(0.1, 0.5))
	tile_m.albedo_color = sand
	tile_m.roughness    = rng.randf_range(0.7, 0.95)

	var tile := MeshInstance3D.new()
	var bm   := BoxMesh.new()
	bm.size  = Vector3(CHUNK_SIZE, 0.4, CHUNK_SIZE)
	bm.material = tile_m
	tile.mesh   = bm
	tile.position = Vector3(0, -0.2, 0)
	chunk.add_child(tile)

	# Collision for the tile (so player can stand on it)
	var sb  := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CHUNK_SIZE, 0.4, CHUNK_SIZE)
	col.shape = box
	col.position = Vector3(0, -0.2, 0)
	sb.add_child(col)
	chunk.add_child(sb)

	# Grains of sand — tiny pebble objects scattered on tile
	var grain_count := rng.randi_range(8, 20)
	for _i in grain_count:
		var gm    := StandardMaterial3D.new()
		gm.albedo_color = sand.darkened(rng.randf_range(0.0, 0.4)).lightened(rng.randf_range(0.0, 0.2))
		gm.roughness    = 0.9
		var gsm   := SphereMesh.new()
		var gr    := rng.randf_range(GRAIN_SIZE * 0.3, GRAIN_SIZE)
		gsm.radius          = gr
		gsm.height          = gr * 2.0
		gsm.radial_segments = 4
		gsm.rings           = 2
		gsm.material        = gm
		var gmi   := MeshInstance3D.new()
		gmi.mesh  = gsm
		gmi.position = Vector3(
			rng.randf_range(-CHUNK_SIZE * 0.45, CHUNK_SIZE * 0.45),
			gr,
			rng.randf_range(-CHUNK_SIZE * 0.45, CHUNK_SIZE * 0.45)
		)
		chunk.add_child(gmi)

	# Occasional rock (darker, bigger)
	if rng.randf() < 0.35:
		var rm    := StandardMaterial3D.new()
		rm.albedo_color = surface_color.darkened(0.5)
		rm.roughness    = 0.95
		var rsm   := SphereMesh.new()
		var rr    := rng.randf_range(2.0, 6.0)
		rsm.radius          = rr
		rsm.height          = rr * 1.4
		rsm.radial_segments = 6
		rsm.rings           = 4
		rsm.material        = rm
		var rmi   := MeshInstance3D.new()
		rmi.mesh  = rsm
		rmi.position = Vector3(
			rng.randf_range(-20.0, 20.0),
			rr * 0.5,
			rng.randf_range(-20.0, 20.0)
		)
		chunk.add_child(rmi)

# ── atmosphere halo ────────────────────────────────────────────────────────

func _build_atmosphere() -> void:
	var sm  := SphereMesh.new()
	sm.radius          = radius * 1.08
	sm.height          = radius * 2.16
	sm.radial_segments = 16
	sm.rings           = 10

	var m   := StandardMaterial3D.new()
	var atm_col := surface_color.lightened(0.5)
	m.albedo_color  = Color(atm_col.r, atm_col.g, atm_col.b, 0.12)
	m.emission_enabled          = true
	m.emission                  = surface_color.lightened(0.2)
	m.emission_energy_multiplier = 0.3
	m.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode     = BaseMaterial3D.CULL_FRONT   # render inside-out for halo effect
	m.roughness     = 1.0
	sm.material     = m

	_atmo = MeshInstance3D.new()
	_atmo.mesh    = sm
	_atmo.visible = false
	add_child(_atmo)

# ── name label ────────────────────────────────────────────────────────────

func _build_name_label() -> void:
	_name_lbl = Label3D.new()
	_name_lbl.text       = name_label
	_name_lbl.pixel_size = 0.8
	_name_lbl.position   = Vector3(0, radius * 1.15, 0)
	_name_lbl.billboard  = BaseMaterial3D.BILLBOARD_ENABLED
	_name_lbl.modulate   = Color(0.8, 0.9, 1.0, 0.7)
	add_child(_name_lbl)
