extends RigidBody3D
# PhysicsBody — any object that responds to gravity wells.
# Player, ship, cargo crate, loose bolt — all use this.
# Registers itself with wells it enters, accumulates forces each frame.

var _active_wells: Array[Area3D] = []

func _ready() -> void:
	gravity_scale = 0.0   # disable Godot's flat gravity entirely
	contact_monitor = true
	max_contacts_reported = 4

func register_well(well: Area3D) -> void:
	if well not in _active_wells:
		_active_wells.append(well)

func unregister_well(well: Area3D) -> void:
	_active_wells.erase(well)

func _physics_process(_delta: float) -> void:
	# Sum all gravity forces from every well currently influencing this body
	var total_force := Vector3.ZERO
	for well: Area3D in _active_wells:
		if is_instance_valid(well):
			total_force += well.pull_force(global_position)
		else:
			_active_wells.erase(well)
	apply_central_force(total_force * mass)
