class_name MechaCombat
extends Node
## MechaCombat — combat brain attached to MechaLodPhysics.
## Handles targeting, fire cadence, and LOD-scaled attack behaviour.
##
## LOD 0/1  — no attacks fired (too distant)
## LOD 2    — whole-body lurch charge; fires burst at closest target
## LOD 3    — per-limb weapon fire with stagger impulse on hit

signal target_acquired(target: Node3D)
signal fired(damage: float, direction: Vector3)

const SCAN_RANGE  := 160.0   # metres — look for targets within this
const FIRE_RATE   := 1.6     # seconds between shots at LOD2
const FIRE_RATE_3 := 0.75    # faster cadence up close (LOD3)
const SHOT_DAMAGE := 12.0
const LURCH_FORCE := 28.0    # push velocity for LOD2 lurch attack

var mecha: MechaLodPhysics = null  # set by MechaLodPhysics._ready()

var _target:      Node3D = null
var _fire_timer:  float  = 0.0
var _alive:       bool   = true


# DNA: MUTATE_GLOBAL | tick targeting + fire each frame when close enough
func _process(delta: float) -> void:
	if not _alive or mecha == null:
		return
	var lod := mecha.get_lod()
	if lod < 2:
		return  # too far — no combat simulation
	_fire_timer -= delta
	if _target == null or not is_instance_valid(_target):
		_scan_for_target()
	if _target == null:
		return
	# Drive mecha toward target
	mecha.target_pos = _target.global_position
	# LOD2 burst fire
	if lod == 2 and _fire_timer <= 0.0:
		_fire_timer = FIRE_RATE
		_burst_lod2()
	# LOD3 precise shot
	elif lod == 3 and _fire_timer <= 0.0:
		_fire_timer = FIRE_RATE_3
		_shoot_lod3()


# DNA: QUERY_NODE | find nearest ship_controller or player node in range
func _scan_for_target() -> Node3D:
	var best: Node3D = null
	var best_dist := SCAN_RANGE
	for group_name: String in ["ships", "player"]:
		for node: Node in mecha.get_tree().get_nodes_in_group(group_name):
			if not node is Node3D:
				continue
			var n := node as Node3D
			if n == mecha:
				continue
			var d := mecha.global_position.distance_to(n.global_position)
			if d < best_dist:
				best_dist = d
				best = n
	if best != null and best != _target:
		_target = best
		target_acquired.emit(_target)
	return _target


# DNA: MUTATE_GLOBAL | LOD2 lurch + burst — whole-body charge at target
func _burst_lod2() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var dir := (_target.global_position - mecha.global_position).normalized()
	# Lurch impulse toward target
	mecha.velocity += dir * LURCH_FORCE * 0.5
	# Deal damage if target has take_hit
	if _target.has_method("take_hit"):
		_target.take_hit(SHOT_DAMAGE * 0.7, dir, mecha.get_lod())
	elif _target.has_method("receive_damage"):
		_target.receive_damage(SHOT_DAMAGE * 0.7)
	fired.emit(SHOT_DAMAGE * 0.7, dir)
	_spawn_shot_vfx(mecha.global_position + dir * 0.8, dir, Color(1.0, 0.65, 0.1))


# DNA: MUTATE_GLOBAL | LOD3 precise shot from right-arm barrel pivot
func _shoot_lod3() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var origin := mecha.global_position + Vector3(0.38, 0.62, -0.14)  # approx barrel
	var dir    := (_target.global_position - origin).normalized()
	if _target.has_method("take_hit"):
		_target.take_hit(SHOT_DAMAGE, dir, mecha.get_lod())
	elif _target.has_method("receive_damage"):
		_target.receive_damage(SHOT_DAMAGE)
	# Kickback: small arm impulse on self
	mecha.apply_impulse(-dir * 2.2, origin)
	fired.emit(SHOT_DAMAGE, dir)
	_spawn_shot_vfx(origin, dir, Color(1.0, 0.82, 0.18))


# DNA: TREE_STRUCTURE | brief bright projectile tracer that flies toward target
func _spawn_shot_vfx(origin: Vector3, dir: Vector3, col: Color) -> void:
	var tracer := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius    = 0.018
	cm.bottom_radius = 0.018
	cm.height        = 0.55
	cm.radial_segments = 5
	tracer.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color      = col
	mat.emission_enabled  = true
	mat.emission          = col * 3.2
	mat.transparency      = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a    = 0.85
	tracer.material_override = mat
	tracer.global_position   = origin
	# Rotate cylinder to face direction of travel
	if dir.length() > 0.01:
		tracer.look_at(origin + dir, Vector3.UP)
		tracer.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	mecha.get_parent().add_child(tracer)
	# Fly and fade
	var tw := mecha.create_tween()
	tw.tween_property(tracer, "global_position", origin + dir * 80.0, 0.22)
	tw.parallel().tween_property(tracer, "scale", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(tracer.queue_free)


# DNA: MUTATE_GLOBAL | called when the owning mecha is destroyed
func on_mecha_destroyed() -> void:
	_alive = false
	_target = null
