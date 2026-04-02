extends Node3D
## landing_demo — standalone proof-of-concept scene
## TREE_STRUCTURE — builds everything in code, no .tscn needed
##
## Tests: astronaut body visible, gravity on foot, G key to board ship
## Run from Project → Run Specific Scene → scenes/landing_demo.tscn
## OR change project.godot run/main_scene temporarily to res://scenes/landing_demo.tscn

var _player: PlayerBody = null
var _ship_marker: Node3D = null
var _well: GravityWell   = null
var _hud: Label          = null

func _ready() -> void:
	_build_lighting()
	_build_surface()
	_build_gravity()
	_build_ship_marker()
	_spawn_player()
	_build_hud()

# ── lighting ───────────────────────────────────────────────────────────────

func _build_lighting() -> void:
	## TREE_STRUCTURE
	var env := WorldEnvironment.new()
	var e   := Environment.new()
	e.background_mode        = Environment.BG_COLOR
	e.background_color       = Color(0.003, 0.003, 0.015)
	e.ambient_light_color    = Color(0.12, 0.12, 0.18)
	e.ambient_light_energy   = 0.6
	env.environment          = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees     = Vector3(-35, 40, 0)
	sun.light_color          = Color(1.0, 0.92, 0.78)
	sun.light_energy         = 1.4
	sun.shadow_enabled       = true
	add_child(sun)

# ── surface ────────────────────────────────────────────────────────────────

func _build_surface() -> void:
	## TREE_STRUCTURE — flat rocky disc, radius 80m
	var mat   := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.19, 0.16)
	mat.roughness    = 0.85

	var mesh  := CylinderMesh.new()
	mesh.top_radius    = 80.0
	mesh.bottom_radius = 80.0
	mesh.height        = 4.0
	mesh.radial_segments = 32
	mesh.material      = mat

	var mi   := MeshInstance3D.new()
	mi.mesh   = mesh
	mi.position = Vector3(0, -2.0, 0)
	add_child(mi)

	# collision
	var body  := StaticBody3D.new()
	var col   := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 80.0
	shape.height = 4.0
	col.shape    = shape
	body.add_child(col)
	body.position = Vector3(0, -2.0, 0)
	add_child(body)

	# horizon ring
	for i in 12:
		var rock   := MeshInstance3D.new()
		var rm     := SphereMesh.new()
		rm.radius  = randf_range(1.5, 3.5)
		rm.height  = rm.radius * 2.0
		rm.radial_segments = 6
		rm.rings   = 4
		rm.material = mat
		rock.mesh   = rm
		var angle   := i * (TAU / 12.0) + randf() * 0.5
		var dist    := 55.0 + randf() * 18.0
		rock.position = Vector3(cos(angle) * dist, 0.8, sin(angle) * dist)
		add_child(rock)

# ── gravity well ───────────────────────────────────────────────────────────

func _build_gravity() -> void:
	## TREE_STRUCTURE — single downward well, radius 200m
	var well_node := Node3D.new()
	well_node.set_script(load("res://scripts/gravity_well.gd"))
	well_node.name = "DemoWell"
	well_node.position = Vector3(0, -2.0, 0)   # centre of the disc
	add_child(well_node)
	_well = well_node as GravityWell
	# Override after _ready() runs — planet-surface feel (≈9.8 m/s² at 2m height)
	_well.grav_param      = 9.8 * 4.0          # g × floor_distance²
	_well.influence_radius = 200.0

# ── ship marker ────────────────────────────────────────────────────────────

func _build_ship_marker() -> void:
	## TREE_STRUCTURE — a grounded ship silhouette 30m away, press G within 15m to board
	_ship_marker = Node3D.new()
	_ship_marker.name = "ShipMarker"
	_ship_marker.position = Vector3(28.0, 1.0, 0.0)
	add_child(_ship_marker)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.60, 0.65)
	mat.metallic     = 0.7
	mat.roughness    = 0.3

	# fuselage
	var f_mesh := CapsuleMesh.new()
	f_mesh.radius = 1.8
	f_mesh.height = 8.0
	f_mesh.material = mat
	var f_mi  := MeshInstance3D.new()
	f_mi.mesh  = f_mesh
	f_mi.rotation_degrees = Vector3(0, 0, 90)
	f_mi.position         = Vector3(0, 2.0, 0)
	_ship_marker.add_child(f_mi)

	# cockpit dome
	var c_mesh := SphereMesh.new()
	c_mesh.radius   = 1.1
	c_mesh.height   = 2.2
	c_mesh.material = mat
	var c_mi  := MeshInstance3D.new()
	c_mi.mesh  = c_mesh
	c_mi.position = Vector3(3.2, 2.8, 0)
	_ship_marker.add_child(c_mi)

	# board prompt (Label3D)
	var lbl := Label3D.new()
	lbl.text       = "[ G ] board"
	lbl.pixel_size = 0.018
	lbl.position   = Vector3(0, 5.2, 0)
	lbl.billboard  = BaseMaterial3D.BILLBOARD_ENABLED
	_ship_marker.add_child(lbl)

# ── player ─────────────────────────────────────────────────────────────────

func _spawn_player() -> void:
	## TREE_STRUCTURE — spawns PlayerBody with collision, camera, suit mesh, gravity well
	var p   := CharacterBody3D.new()
	p.set_script(load("res://scripts/player_body.gd"))

	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.70
	var col   := CollisionShape3D.new()
	col.shape  = cap
	p.add_child(col)

	add_child(p)
	p.global_position = Vector3(0.0, 2.2, 0.0)
	_player = p as PlayerBody

	# register the gravity well so player sticks to the surface
	if is_instance_valid(_well):
		_player.call("add_well", _well)

# ── hud ────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	## TREE_STRUCTURE — minimal top-left overlay
	var canvas  := CanvasLayer.new()
	_hud = Label.new()
	_hud.position         = Vector2(12, 10)
	_hud.add_theme_font_size_override("font_size", 12)
	_hud.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	canvas.add_child(_hud)
	add_child(canvas)

func _process(_delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_ship_marker):
		return
	var dist := _player.global_position.distance_to(_ship_marker.global_position)
	var credits: int = 1000
	if has_node("/root/GameState"):
		credits = get_node("/root/GameState").credits
	_hud.text = "LANDING DEMO\nWASD walk • SPACE jetpack\nShip: %.0fm  |  Credits: %d" % [dist, credits]

# ── G key — board ship ─────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	## MUTATE_GLOBAL — G boards ship when close enough
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode != KEY_G: return
	if not is_instance_valid(_player) or not is_instance_valid(_ship_marker): return
	var dist := _player.global_position.distance_to(_ship_marker.global_position)
	if dist > 15.0:
		return
	# board — despawn player, release mouse, load main game
	_player.queue_free()
	_player = null
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if has_node("/root/GameState"):
		get_node("/root/GameState").save_game()
	# switch to main scene
	get_tree().change_scene_to_file("res://scenes/main.tscn")
