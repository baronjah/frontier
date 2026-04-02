extends RigidBody3D
class_name GravityBody

# Any passive physics object: cargo crate, loose panel, dropped tool.
# Responds to all GravityWells it enters. Nothing else needed.

var _wells: Array[GravityWell] = []

@export var density:      float = 1000.0   # kg/m³ equivalent
@export var shape_radius: float = 0.5      # metres

func _ready() -> void:
	mass            = density * (4.0 / 3.0) * PI * shape_radius * shape_radius * shape_radius
	gravity_scale   = 0.0
	contact_monitor = true
	max_contacts_reported = 4

func add_well(w: GravityWell) -> void:
	if w not in _wells:
		_wells.append(w)

func remove_well(w: GravityWell) -> void:
	_wells.erase(w)

func _physics_process(_delta: float) -> void:
	for w: GravityWell in _wells:
		if is_instance_valid(w):
			apply_central_force(w.accel_at(global_position) * mass)
		else:
			_wells.erase(w)
