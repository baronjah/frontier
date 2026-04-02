extends CharacterBody3D
class_name PlayerBody

# HOW THE CAMERA/ORIENTATION WORKS — read before touching anything here
# ─────────────────────────────────────────────────────────────────────
# The CharacterBody3D IS the player orientation. Its Y axis = "up" (away from gravity).
# Its -Z axis = "forward" (where you look horizontally).
#
# Mouse X (yaw):  global_rotate(basis.y, angle) rotates the body around its own up.
#                 Works at any surface orientation — no world-Y assumption anywhere.
# Mouse Y (pitch): only tilts the camera child on its X axis. Body stays upright.
#
# _align_to_surface() runs EVERY frame:
#   1. Slerps _surface_up toward gravity's "up" direction (smoothly, not instant).
#   2. Reads current -basis.z (the mouse-rotated forward).
#   3. Projects it onto the new surface plane (removes any surface-normal component).
#   4. Rebuilds global_transform.basis = Basis(right, up, -forward).
#   Result: body is always upright relative to gravity, AND mouse yaw is preserved.
#
# HOW GRAVITY TRANSITIONS WORK
# ─────────────────────────────
# GravityWell (Area3D) signals add_well/remove_well when player enters/exits.
# _accumulate_gravity() sums ALL active wells each frame.
# Multiple wells active at once = gravity is the vector sum (correct physics).
# _surface_up slerps at UP_SMOOTH rate so orientation feels smooth, not snappy.
# CharacterBody3D.up_direction is set to _surface_up so is_on_floor() is relative
# to whatever surface the player currently stands on.
#
# NEVER change _align_to_surface to only run when is_on_floor() — that freezes
# yaw when airborne, making the camera only rotate up/down.

var _wells: Array[GravityWell] = []
var _gravity_accel: Vector3    = Vector3.DOWN * 9.8
var _surface_up: Vector3       = Vector3.UP
var _holding: GravityBody      = null
var _charging_door             = null
var _cam:     Camera3D
var _cam_3p:  Camera3D
var _cam_mode: int = 0          # 0 = first-person  1 = third-person

var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _anim:  AnimationPlayer
var _was_moving: bool = false

const WALK_SPEED     := 6.0
const JUMP_SPEED     := 7.0
const JETPACK_FORCE  := 4.5    # weaker than any surface gravity — hover, not rocket
const MAX_RISE_SPEED := 5.0    # tight cap so you can't escape the planet by holding Space
const MOUSE_SENS     := 0.0018
const GRAB_REACH     := 3.8
const HOLD_OFFSET    := 1.6
const UP_SMOOTH      := 6.0

var _pitch: float = 0.0

func _ready() -> void:
	_cam          = Camera3D.new()
	_cam.position = Vector3(0, 0.72, 0)
	_cam.fov      = 85
	_cam.far      = 200000.0
	add_child(_cam)
	_cam.make_current()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_build_body_mesh()
	_build_limbs()
	_build_animations()
	_build_third_person_cam()

func _build_body_mesh() -> void:
	## TREE_STRUCTURE — astronaut suit: torso capsule + helmet sphere
	# torso
	var torso_m := CapsuleMesh.new()
	torso_m.radius = 0.30
	torso_m.height = 1.10
	var torso := MeshInstance3D.new()
	torso.name     = "torso"
	torso.mesh     = torso_m
	torso.position = Vector3(0.0, -0.08, 0.0)   # chest below camera
	var suit_mat   := StandardMaterial3D.new()
	suit_mat.albedo_color = Color(0.85, 0.87, 0.92)   # off-white EVA suit
	torso_m.material      = suit_mat
	add_child(torso)
	# visor
	var helm_m  := SphereMesh.new()
	helm_m.radius         = 0.26
	helm_m.height         = 0.52
	helm_m.radial_segments = 12
	helm_m.rings           = 6
	var helm  := MeshInstance3D.new()
	helm.mesh     = helm_m
	helm.position = Vector3(0.0, 0.63, 0.0)   # just below first-person camera
	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color    = Color(0.2, 0.4, 0.9, 0.6)
	visor_mat.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
	visor_mat.roughness       = 0.1
	visor_mat.metallic        = 0.8
	helm_m.material           = visor_mat
	add_child(helm)

# ── limbs ──────────────────────────────────────────────────────────────────

func _build_limbs() -> void:
	## TREE_STRUCTURE — leg/arm pivot nodes for walk animation
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.85, 0.87, 0.92)
	_leg_l = _limb_pivot("left_leg",  Vector3(-0.16, -0.32, 0.0), 0.12, 0.55, sm)
	_leg_r = _limb_pivot("right_leg", Vector3( 0.16, -0.32, 0.0), 0.12, 0.55, sm)
	_arm_l = _limb_pivot("left_arm",  Vector3(-0.38,  0.10, 0.0), 0.09, 0.44, sm)
	_arm_r = _limb_pivot("right_arm", Vector3( 0.38,  0.10, 0.0), 0.09, 0.44, sm)

func _limb_pivot(n: String, pos: Vector3, r: float, h: float,
		mat: StandardMaterial3D) -> Node3D:
	## TREE_STRUCTURE — pivot node at joint, capsule mesh hangs below
	var pivot := Node3D.new()
	pivot.name     = n
	pivot.position = pos
	var cm := CapsuleMesh.new()
	cm.radius = r; cm.height = h; cm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh     = cm
	mi.position = Vector3(0, -h * 0.5, 0)   # hang below pivot
	pivot.add_child(mi)
	add_child(pivot)
	return pivot

# ── walk animation ─────────────────────────────────────────────────────────

func _build_animations() -> void:
	## TREE_STRUCTURE — AnimationPlayer with "walk" + "idle" keyframe cycles
	_anim = AnimationPlayer.new()
	_anim.name = "Anim"
	add_child(_anim)

	var lib  := AnimationLibrary.new()
	var LSWING := deg_to_rad(26.0)
	var ASWING := deg_to_rad(16.0)
	var DUR    := 0.65   # full stride

	# ── walk ──────────────────────────────────────────────────────────────
	var walk := Animation.new()
	walk.length    = DUR
	walk.loop_mode = Animation.LOOP_LINEAR

	for row: Array in [
		["left_leg:rotation:x",   LSWING, -LSWING,  LSWING],
		["right_leg:rotation:x", -LSWING,  LSWING, -LSWING],
		["left_arm:rotation:x",  -ASWING,  ASWING, -ASWING],
		["right_arm:rotation:x",  ASWING, -ASWING,  ASWING],
	]:
		var t := walk.add_track(Animation.TYPE_VALUE)
		walk.track_set_path(t, NodePath(row[0]))
		walk.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		walk.track_insert_key(t, 0.0,       row[1])
		walk.track_insert_key(t, DUR * 0.5, row[2])
		walk.track_insert_key(t, DUR,       row[3])

	# torso bob (position y)
	var tb := walk.add_track(Animation.TYPE_VALUE)
	walk.track_set_path(tb, NodePath("torso:position:y"))
	walk.track_set_interpolation_type(tb, Animation.INTERPOLATION_CUBIC)
	walk.track_insert_key(tb, 0.0,        -0.08)
	walk.track_insert_key(tb, DUR * 0.25, -0.04)
	walk.track_insert_key(tb, DUR * 0.5,  -0.08)
	walk.track_insert_key(tb, DUR * 0.75, -0.04)
	walk.track_insert_key(tb, DUR,        -0.08)

	lib.add_animation("walk", walk)

	# ── idle (breathe) ────────────────────────────────────────────────────
	var idle := Animation.new()
	idle.length    = 2.0
	idle.loop_mode = Animation.LOOP_LINEAR

	for path: String in ["left_leg:rotation:x","right_leg:rotation:x",
			"left_arm:rotation:x","right_arm:rotation:x"]:
		var ti := idle.add_track(Animation.TYPE_VALUE)
		idle.track_set_path(ti, NodePath(path))
		idle.track_insert_key(ti, 0.0, 0.0)
		idle.track_insert_key(ti, 2.0, 0.0)

	var ib := idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(ib, NodePath("torso:position:y"))
	idle.track_set_interpolation_type(ib, Animation.INTERPOLATION_CUBIC)
	idle.track_insert_key(ib, 0.0, -0.08)
	idle.track_insert_key(ib, 1.0, -0.05)
	idle.track_insert_key(ib, 2.0, -0.08)

	lib.add_animation("idle", idle)

	_anim.add_animation_library("", lib)
	_anim.play("idle")

func _update_body_anim(wish: Vector3) -> void:
	## MUTATE_GLOBAL — switches walk/idle based on movement
	if not is_instance_valid(_anim): return
	var moving := wish.length_squared() > 0.01 and is_on_floor()
	if moving == _was_moving: return
	_was_moving = moving
	_anim.play("walk" if moving else "idle")

# ── cameras ─────────────────────────────────────────────────────────────────

func _build_third_person_cam() -> void:
	## TREE_STRUCTURE — 3rd-person camera behind/above player, C to toggle
	_cam_3p          = Camera3D.new()
	_cam_3p.name     = "CamThird"
	_cam_3p.position = Vector3(0, 2.2, 3.4)
	_cam_3p.rotation.x = deg_to_rad(-14)
	_cam_3p.fov      = 72
	_cam_3p.far      = 200000.0
	add_child(_cam_3p)
	# inactive until C pressed

func _toggle_cam() -> void:
	## MUTATE_GLOBAL — flips between first/third person camera
	_cam_mode = 1 - _cam_mode
	if _cam_mode == 0:
		_cam.make_current()
	else:
		_cam_3p.make_current()

# ── well registration ──────────────────────────────────────────────────────

func add_well(w: GravityWell) -> void:
	if w not in _wells:
		_wells.append(w)

func remove_well(w: GravityWell) -> void:
	_wells.erase(w)

# ── input ──────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Yaw: rotate body around its own up axis — correct at any surface orientation
		global_rotate(global_transform.basis.y, -event.relative.x * MOUSE_SENS)
		# Pitch: tilt camera only, not the whole body
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.45, 1.45)
		_cam.rotation.x = _pitch

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey): return
	var ke := event as InputEventKey
	if ke.keycode == KEY_ESCAPE and ke.pressed:
		get_tree().quit()
	if ke.keycode == KEY_C and ke.pressed:
		_toggle_cam()
	if ke.keycode == KEY_F and ke.pressed:
		if _holding:
			_drop()
		elif _charging_door == null:
			_try_grab()
	if ke.keycode == KEY_G and ke.pressed:
		var p := get_parent()
		if p and p.has_method("try_enter_ship"):
			p.try_enter_ship(self)

# ── physics ────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	_accumulate_gravity()
	_align_to_surface(delta)
	_walk(delta)
	_update_held_object()
	_update_telekinesis(delta)
	move_and_slide()

func _accumulate_gravity() -> void:
	var total := Vector3.ZERO
	for w: GravityWell in _wells:
		if is_instance_valid(w):
			total += w.accel_at(global_position)
		else:
			_wells.erase(w)
	if total.length_squared() > 0.001:
		_gravity_accel = total

func _align_to_surface(delta: float) -> void:
	if _wells.is_empty():
		# True void — no gravity source, no defined "up".
		# Body keeps its current orientation. Mouse rotates around body's own Y.
		# _surface_up tracks body Y so re-entering gravity slerps from a sane start.
		_surface_up  = global_transform.basis.y
		up_direction = _surface_up
		return

	# Near a gravity source: slerp body up toward gravity up.
	# Preserves current facing (-basis.z) across the reorientation.
	var target_up := -_gravity_accel.normalized()
	_surface_up    = _surface_up.slerp(target_up, delta * UP_SMOOTH).normalized()

	var fwd := -global_transform.basis.z
	fwd = (fwd - _surface_up * fwd.dot(_surface_up)).normalized()
	if fwd.length_squared() < 0.001:
		fwd = _surface_up.cross(Vector3.RIGHT).normalized()
		if fwd.length_squared() < 0.001:
			fwd = _surface_up.cross(Vector3.FORWARD).normalized()
	var rgt := fwd.cross(_surface_up).normalized()
	global_transform.basis = Basis(rgt, _surface_up, -fwd)
	up_direction = _surface_up

func _walk(delta: float) -> void:
	var in_gravity := not _wells.is_empty()
	var grav_n     := _gravity_accel.normalized() if in_gravity else Vector3.ZERO
	if in_gravity:
		velocity += _gravity_accel * delta

	# Movement directions: body basis projected off gravity axis.
	# In void grav_n is zero so projection is a no-op — raw body axes are used,
	# which may point in any direction (correct for free-space flight).
	var raw_fwd := -global_transform.basis.z
	var raw_rgt :=  global_transform.basis.x
	var fwd := raw_fwd - grav_n * raw_fwd.dot(grav_n)
	var rgt := raw_rgt - grav_n * raw_rgt.dot(grav_n)
	if fwd.length_squared() > 0.001: fwd = fwd.normalized()
	if rgt.length_squared() > 0.001: rgt = rgt.normalized()

	var wish := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): wish += fwd
	if Input.is_key_pressed(KEY_S): wish -= fwd
	if Input.is_key_pressed(KEY_A): wish -= rgt
	if Input.is_key_pressed(KEY_D): wish += rgt
	_update_body_anim(wish)

	# Split velocity into vertical (gravity axis) and lateral (horizontal) parts.
	var grav_comp := grav_n * velocity.dot(grav_n)
	var lateral   := velocity - grav_comp

	if is_on_floor():
		# On ground: snap lateral to wish immediately (tight, responsive feel).
		if wish.length_squared() > 0.001:
			lateral = wish.normalized() * WALK_SPEED
		else:
			lateral *= (1.0 - minf(delta * 12.0, 1.0))   # friction stop
		velocity = grav_comp + lateral
	else:
		# Airborne: grav_comp is NEVER touched — jump momentum is preserved.
		# Only gently nudge lateral toward wish so you can steer but not kill the arc.
		if wish.length_squared() > 0.001:
			lateral = lateral.lerp(wish.normalized() * WALK_SPEED * 0.6, delta * 3.0)
		velocity = grav_comp + lateral

	if Input.is_key_pressed(KEY_SPACE):
		if is_on_floor():
			velocity += _surface_up * JUMP_SPEED
		else:
			# Jetpack: gentle hover force, capped so you can't rocket off the planet
			velocity += _surface_up * JETPACK_FORCE * delta
			var vert_vel := velocity.dot(-grav_n)
			if vert_vel > MAX_RISE_SPEED:
				velocity -= (-grav_n) * (vert_vel - MAX_RISE_SPEED)

# ── grab ───────────────────────────────────────────────────────────────────

func _try_grab() -> void:
	var hit := _raycast()
	if not hit: return
	if hit.collider is GravityBody:
		_holding = hit.collider as GravityBody

func _drop() -> void:
	_holding = null

func _update_held_object() -> void:
	if not _holding or not is_instance_valid(_holding):
		_holding = null
		return
	var target    := _cam.global_position + (-_cam.global_transform.basis.z) * HOLD_OFFSET
	var delta_pos := target - _holding.global_position
	_holding.linear_velocity  = delta_pos * 14.0
	_holding.angular_velocity = Vector3.ZERO

# ── telekinesis ────────────────────────────────────────────────────────────

func _update_telekinesis(delta: float) -> void:
	if _holding: return

	if Input.is_key_pressed(KEY_F):
		if _charging_door == null or not is_instance_valid(_charging_door):
			var hit := _raycast()
			if hit:
				var parent: Node = hit.collider.get_parent()
				if parent != null and parent.has_method("add_charge"):
					_charging_door = parent
		if _charging_door != null and is_instance_valid(_charging_door):
			_charging_door.add_charge(delta)
	else:
		# Door handles its own bleed — we just stop calling add_charge
		_charging_door = null

# ── shared raycast ─────────────────────────────────────────────────────────

func _raycast() -> Dictionary:
	var space  := get_world_3d().direct_space_state
	var origin := _cam.global_position
	var tip    := origin + (-_cam.global_transform.basis.z) * GRAB_REACH
	var query  := PhysicsRayQueryParameters3D.create(origin, tip)
	query.exclude = [get_rid()]
	return space.intersect_ray(query)
