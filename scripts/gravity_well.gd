extends Area3D
class_name GravityWell

# Every mass emits this. Bodies register/deregister via Area3D signals.
# accel_at(pos) returns acceleration (m/s²) toward this well's center.
#
# By default, grav_param and influence_radius are derived from density/radius:
#   mass         = density * (4/3 * PI * radius³)
#   grav_param   = G_SCALED * mass
#   influence_radius = radius * influence_scale
#
# You can OVERRIDE them after add_child() to set gravity directly:
#   well.grav_param      = desired_g * floor_distance²
#   well.influence_radius = how far the field reaches
# This is how platform_ship.gd provides strong artificial floor gravity
# without needing a physically plausible mass/density.
#
# Multiple wells can be active on the same body simultaneously.
# The body sums all accelerations — this is correct additive gravity.

const G_SCALED := 0.000004   # tuned: rocky body r=60, density=3000 → surface g ≈ 5 m/s²

@export var density: float          = 3000.0   # kg/m³ equivalent (rock=3000, steel=7800, ice=900)
@export var radius:  float          = 10.0     # physical body radius in metres
@export var influence_scale: float  = 8.0      # influence sphere = radius × this

var grav_param:      float
var influence_radius: float

func _ready() -> void:
	var volume       := (4.0 / 3.0) * PI * radius * radius * radius
	var mass         := density * volume
	grav_param       = G_SCALED * mass
	influence_radius = radius * influence_scale

	monitoring  = true
	monitorable = false
	var shape := SphereShape3D.new()
	shape.radius = influence_radius
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(_entered)
	body_exited.connect(_exited)

func accel_at(pos: Vector3) -> Vector3:
	var delta := global_position - pos
	var d2    := maxf(delta.length_squared(), 0.01)
	return delta.normalized() * (grav_param / d2)

func _entered(body: Node3D) -> void:
	if body.has_method("add_well"):
		body.add_well(self)

func _exited(body: Node3D) -> void:
	if body.has_method("remove_well"):
		body.remove_well(self)
