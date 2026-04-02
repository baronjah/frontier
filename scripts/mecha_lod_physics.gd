class_name MechaLodPhysics
extends Node3D
## MechaLodPhysics — 4-tier LOD physics body for space combat mechas.
##
## Distance from observer drives simulation depth:
##   LOD 0  d > 500m  — ghost dot, position lerp only, zero overhead
##   LOD 1  150-500m  — single box + newtonian velocity integration
##   LOD 2  40-150m   — full kinematics, limb zones, whole-body lurch attacks
##   LOD 3  < 40m     — named limb pivots, keyframe animation, per-limb forces
##
## Usage:
##   var m := MechaLodPhysics.new()
##   m.color = Color(0.8, 0.2, 0.2)
##   add_child(m)
##   m.set_observer(camera_node)

signal lod_changed(from_lod: int, to_lod: int)
signal hit_taken(damage: float, direction: Vector3)
signal destroyed

const DIST_LOD1 := 500.0
const DIST_LOD2 := 150.0
const DIST_LOD3 :=  40.0

@export var color:     Color = Color(0.28, 0.32, 0.40)
@export var max_speed: float = 22.0
@export var thrust:    float = 18.0

var observer:    Node3D  = null
var velocity:    Vector3 = Vector3.ZERO
var target_pos:  Vector3 = Vector3.ZERO
var health:      float   = 100.0
var combat:      MechaCombat = null

var _lod: int = -1

# Named pivots (LOD3 only)
var _torso: Node3D = null
var _head:  Node3D = null
var _arm_l: Node3D = null
var _arm_r: Node3D = null
var _leg_l: Node3D = null
var _leg_r: Node3D = null

# Per-limb physics accumulator (LOD3)
var _arm_l_vel:     Vector3 = Vector3.ZERO
var _arm_r_vel:     Vector3 = Vector3.ZERO
var _torso_wobble:  float   = 0.0

# LOD representations
var _lod0: MeshInstance3D = null
var _lod1: MeshInstance3D = null
var _lod2: Node3D         = null
var _lod3: Node3D         = null

var _thruster_mats: Array[StandardMaterial3D] = []


# DNA: TREE_STRUCTURE | build all LOD layers and attach combat controller
func _ready() -> void:
	_build_lod0()
	_build_lod1()
	_build_lod2()
	_build_lod3()
	combat = MechaCombat.new()
	combat.name = "Combat"
	combat.mecha = self
	add_child(combat)
	destroyed.connect(combat.on_mecha_destroyed)
	_apply_lod(0)


# DNA: MUTATE_GLOBAL | set the observer node used for LOD distance measurement
func set_observer(obs: Node3D) -> void:
	observer = obs


# DNA: MUTATE_GLOBAL | per-frame: measure distance → switch LOD → tick appropriate tier
func _process(delta: float) -> void:
	if observer == null:
		return
	var dist := global_position.distance_to(observer.global_position)
	var want  := _dist_to_lod(dist)
	if want != _lod:
		_apply_lod(want)
	match _lod:
		0: _tick_lod0(delta)
		1: _tick_lod1(delta)
		2: _tick_lod2(delta)
		3: _tick_lod3(delta)


# DNA: RETURN_VALUE | convert distance to LOD integer
func _dist_to_lod(d: float) -> int:
	if d > DIST_LOD1: return 0
	if d > DIST_LOD2: return 1
	if d > DIST_LOD3: return 2
	return 3


# DNA: QUERY_NODE | current LOD level
func get_lod() -> int:
	return _lod


# ── physics ticks ─────────────────────────────────────────────────────────

# DNA: MUTATE_GLOBAL | LOD0 — ghost move, position only
func _tick_lod0(delta: float) -> void:
	if target_pos != Vector3.ZERO:
		global_position = global_position.move_toward(target_pos, max_speed * 0.25 * delta)


# DNA: MUTATE_GLOBAL | LOD1 — newtonian box: velocity + direction
func _tick_lod1(delta: float) -> void:
	var to := target_pos - global_position
	if to.length() > 1.0:
		velocity += to.normalized() * thrust * delta
	velocity = velocity.limit_length(max_speed)
	global_position += velocity * delta
	if velocity.length() > 0.5:
		look_at(global_position + velocity.normalized(), Vector3.UP)


# DNA: MUTATE_GLOBAL | LOD2 — full kinematics + thruster lean on torso pivot
func _tick_lod2(delta: float) -> void:
	var to := target_pos - global_position
	if to.length() > 0.8:
		velocity += to.normalized() * thrust * delta
	velocity = velocity.limit_length(max_speed)
	global_position += velocity * delta
	if velocity.length() > 0.5:
		var want_basis := Basis.looking_at(velocity.normalized(), Vector3.UP)
		transform.basis = transform.basis.slerp(want_basis, delta * 5.0)
	# Thrust lean — tilt torso forward at speed
	if _torso != null:
		var lean := -velocity.dot(transform.basis.z) * 0.045
		_torso.rotation.x = lerpf(_torso.rotation.x, lean, delta * 6.0)


# DNA: MUTATE_GLOBAL | LOD3 — LOD2 base + limb wobble + thruster flame pulse
func _tick_lod3(delta: float) -> void:
	_tick_lod2(delta)
	# Thruster flame flicker
	var t := Time.get_ticks_msec() * 0.001
	for mat: StandardMaterial3D in _thruster_mats:
		mat.emission_energy_multiplier = 1.0 + sin(t * 9.5 + global_position.x) * 0.45
	# Dampen accumulated limb velocities
	_arm_l_vel     = _arm_l_vel.lerp(Vector3.ZERO, delta * 4.2)
	_arm_r_vel     = _arm_r_vel.lerp(Vector3.ZERO, delta * 4.2)
	_torso_wobble  = lerpf(_torso_wobble, 0.0, delta * 3.8)
	if _arm_l != null: _arm_l.rotation += _arm_l_vel * delta
	if _arm_r != null: _arm_r.rotation += _arm_r_vel * delta
	if _torso  != null: _torso.rotation.z = _torso_wobble


# ── public physics interface ───────────────────────────────────────────────

# DNA: MUTATE_GLOBAL | apply impulse at world position — detail scales with LOD
func apply_impulse(force: Vector3, world_pos: Vector3) -> void:
	velocity += force * 0.045
	if _lod < 2:
		return
	var local_hit := to_local(world_pos)
	if _lod == 3:
		_react_lod3(local_hit, force)


# DNA: MUTATE_GLOBAL | LOD3 hit reaction — which limb region was struck?
func _react_lod3(local_pos: Vector3, force: Vector3) -> void:
	_torso_wobble += force.x * 0.14
	if local_pos.x < -0.2:
		_arm_l_vel += Vector3(force.z, force.y, force.x) * 0.22
	elif local_pos.x > 0.2:
		_arm_r_vel += Vector3(-force.z, force.y, -force.x) * 0.22


# DNA: MUTATE_GLOBAL | receive damage — stagger, flash, die
func take_hit(damage: float, direction: Vector3, from_lod: int) -> void:
	health -= damage
	apply_impulse(direction.normalized() * damage * 0.55, global_position)
	if _lod >= 2:
		_flash_hit()
	hit_taken.emit(damage, direction)
	if health <= 0.0:
		_on_destroyed()


# DNA: MUTATE_GLOBAL | brief white flash on hit
func _flash_hit() -> void:
	var tw := create_tween()
	tw.tween_callback(_set_all_emission.bind(3.0))
	tw.tween_interval(0.07)
	tw.tween_callback(_set_all_emission.bind(0.12))


func _set_all_emission(val: float) -> void:
	_set_emission_r(self, val)


func _set_emission_r(node: Node, val: float) -> void:
	if node is MeshInstance3D:
		var mat := (node as MeshInstance3D).material_override as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = val
	for c: Node in node.get_children():
		_set_emission_r(c, val)


# DNA: MUTATE_GLOBAL | shrink to zero then free
func _on_destroyed() -> void:
	destroyed.emit()
	if has_node("/root/LogCatcher"):
		LogCatcher.log("MECHA", "destroyed", name)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.55).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(queue_free)


# ── LOD switch ────────────────────────────────────────────────────────────

# DNA: MUTATE_GLOBAL | hide/show correct representation, emit signal
func _apply_lod(lod: int) -> void:
	var old  := _lod
	_lod = lod
	if _lod0 != null: _lod0.visible = (lod == 0)
	if _lod1 != null: _lod1.visible = (lod == 1)
	if _lod2 != null: _lod2.visible = (lod == 2)
	if _lod3 != null: _lod3.visible = (lod == 3)
	if old != -1:
		lod_changed.emit(old, lod)


# ── LOD builders ──────────────────────────────────────────────────────────

# DNA: TREE_STRUCTURE | LOD0 — bright emissive dot, visible from 500+ m
func _build_lod0() -> void:
	_lod0 = MeshInstance3D.new()
	_lod0.name = "LOD0"
	var sm := SphereMesh.new()
	sm.radius = 0.5; sm.height = 1.0
	sm.radial_segments = 5; sm.rings = 4
	_lod0.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 2.4
	_lod0.material_override = mat
	add_child(_lod0)


# DNA: TREE_STRUCTURE | LOD1 — single box silhouette
func _build_lod1() -> void:
	_lod1 = MeshInstance3D.new()
	_lod1.name = "LOD1"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 1.6, 0.4)
	_lod1.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.55
	_lod1.material_override = mat
	add_child(_lod1)


# DNA: TREE_STRUCTURE | LOD2 — ProceduralBeing mecha, no named pivots
func _build_lod2() -> void:
	_lod2 = ProceduralBeing.build(BeingBlueprints.mecha(color))
	_lod2.name = "LOD2"
	add_child(_lod2)


# DNA: TREE_STRUCTURE | LOD3 — articulated body with named pivot nodes for animation
func _build_lod3() -> void:
	_lod3 = Node3D.new()
	_lod3.name = "LOD3"
	add_child(_lod3)

	var ac := Color(0.9, 0.45, 0.08)
	var dk := color.darkened(0.22)

	# Named pivot groups — position in mecha local space
	_torso = _pivot("Torso", Vector3(0.00,  0.85, 0.00))
	_head  = _pivot("Head",  Vector3(0.00,  1.40, 0.00))
	_arm_l = _pivot("ArmL",  Vector3(-0.38, 0.90, 0.00))
	_arm_r = _pivot("ArmR",  Vector3( 0.38, 0.90, 0.00))
	_leg_l = _pivot("LegL",  Vector3(-0.16, 0.24, 0.00))
	_leg_r = _pivot("LegR",  Vector3( 0.16, 0.24, 0.00))

	# Torso panels
	_panel(_torso, Vector3(0.55, 0.65, 0.14), Vector3(0, 0, -0.07), color)
	_panel(_torso, Vector3(0.55, 0.65, 0.14), Vector3(0, 0,  0.07), dk)
	_panel(_torso, Vector3(0.42, 0.08, 0.18), Vector3(0, 0.20, 0), ac)   # chest vent

	# Head
	_panel(_head, Vector3(0.30, 0.26, 0.26), Vector3.ZERO, color.lightened(0.1))
	_panel(_head, Vector3(0.22, 0.08, 0.06), Vector3(0, 0.03, -0.14), ac.lightened(0.3))  # visor

	# Arms
	for side: int in [0, 1]:
		var pivot := _arm_l if side == 0 else _arm_r
		var sx    := -1.0 if side == 0 else 1.0
		_panel(pivot, Vector3(0.18, 0.24, 0.22), Vector3(0,  0.10, 0), color.lightened(0.05))   # shoulder
		_panel(pivot, Vector3(0.13, 0.30, 0.13), Vector3(0, -0.18, 0), color)                    # forearm
		# Weapon barrel on right arm
		if side == 1:
			_panel(pivot, Vector3(0.05, 0.05, 0.28), Vector3(0.08, -0.28, -0.14), ac)

	# Legs
	for side: int in [0, 1]:
		var pivot := _leg_l if side == 0 else _leg_r
		_panel(pivot, Vector3(0.18, 0.36, 0.18), Vector3.ZERO, color)
		_panel(pivot, Vector3(0.16, 0.32, 0.16), Vector3(0, -0.34, 0), color.lightened(0.05))   # shin

	# Pelvis (direct child of body)
	_panel(_lod3, Vector3(0.48, 0.14, 0.22), Vector3(0, 0.48, 0), dk)

	# Back thrusters
	_lod3.add_child(_thruster_node(Vector3(-0.18, 0.96, 0.16), ac))
	_lod3.add_child(_thruster_node(Vector3( 0.18, 0.96, 0.16), ac))


# DNA: RETURN_VALUE | create a named Node3D pivot at given local position
func _pivot(pname: String, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = pname
	p.position = pos
	_lod3.add_child(p)
	return p


# DNA: RETURN_VALUE | add a box-mesh panel as child of parent pivot
func _panel(parent: Node3D, size: Vector3, offset: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness    = 0.62
	mat.metallic     = 0.45
	mat.emission_enabled = true
	mat.emission = col * 0.10
	mi.material_override = mat
	parent.add_child(mi)
	return mi


# DNA: TREE_STRUCTURE | build a thruster bell Node3D at given position
func _thruster_node(pos: Vector3, col: Color) -> Node3D:
	var t := Node3D.new()
	t.position = pos
	t.rotation_degrees.x = -90.0

	var bell := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.052; cm.bottom_radius = 0.095
	cm.height = 0.18; cm.radial_segments = 8
	bell.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col * 1.3
	mat.emission_energy_multiplier = 1.0
	bell.material_override = mat
	_thruster_mats.append(mat)
	t.add_child(bell)

	# Flame cone
	var flame := MeshInstance3D.new()
	var fc := CylinderMesh.new()
	fc.top_radius = 0.0; fc.bottom_radius = 0.085
	fc.height = 0.14; fc.radial_segments = 8
	flame.mesh = fc
	flame.position.y = -0.13
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color   = col.lightened(0.45)
	fmat.emission_enabled = true
	fmat.emission       = col.lightened(0.45) * 2.2
	fmat.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.albedo_color.a = 0.55
	flame.material_override = fmat
	_thruster_mats.append(fmat)
	t.add_child(flame)

	return t
