class_name Location
extends Node3D
# FRONTIER × SPACE DANDY — Location data node
# Attach to any dockable body in the scene. World populates market dict.

@export var loc_name: String    = "Unknown"
@export var loc_type: String    = "PLANET"    # PLANET / STATION / SHIPYARD
@export var dock_radius: float  = 400.0
var market: Dictionary          = {}          # {good_name: {buy, sell, qty}}
