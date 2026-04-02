class_name BeingBlueprints
## BeingBlueprints — ready-made ProceduralBeing blueprints.
## RETURN_VALUE — all methods return Dictionary for ProceduralBeing.build()
##
## Usage:
##   var alien := ProceduralBeing.build(BeingBlueprints.humanoid_alien(Color(0.4,0.8,0.3)))
##   add_child(alien)

static func humanoid_alien(color: Color = Color(0.55, 0.18, 0.75)) -> Dictionary:
	## RETURN_VALUE — bipedal alien: spine + head + arms + legs + eyes
	var c  := color
	var dc := c.darkened(0.3)
	var lc := c.lightened(0.4)
	return { "parts": [
		# spine
		{"type":"bone",  "length":0.6,  "radius":0.10, "color":dc,  "pos":Vector3(0, 0.9, 0)},
		# head
		{"type":"joint", "radius":0.20, "color":c,     "pos":Vector3(0, 1.45, 0)},
		# eyes
		{"type":"eye",   "radius":0.055,"color":lc,    "pos":Vector3(-0.08, 1.50, -0.17)},
		{"type":"eye",   "radius":0.055,"color":lc,    "pos":Vector3( 0.08, 1.50, -0.17)},
		# shoulder joints
		{"type":"joint", "radius":0.10, "color":dc,    "pos":Vector3(-0.22, 1.18, 0)},
		{"type":"joint", "radius":0.10, "color":dc,    "pos":Vector3( 0.22, 1.18, 0)},
		# upper arms
		{"type":"bone",  "length":0.32, "radius":0.07, "color":c,   "pos":Vector3(-0.30, 0.98, 0), "rot":Vector3(0,0, 30)},
		{"type":"bone",  "length":0.32, "radius":0.07, "color":c,   "pos":Vector3( 0.30, 0.98, 0), "rot":Vector3(0,0,-30)},
		# forearms
		{"type":"bone",  "length":0.28, "radius":0.055,"color":dc,  "pos":Vector3(-0.38, 0.68, 0), "rot":Vector3(0,0, 18)},
		{"type":"bone",  "length":0.28, "radius":0.055,"color":dc,  "pos":Vector3( 0.38, 0.68, 0), "rot":Vector3(0,0,-18)},
		# pelvis joint
		{"type":"joint", "radius":0.13, "color":dc,    "pos":Vector3(0, 0.55, 0)},
		# upper legs
		{"type":"bone",  "length":0.38, "radius":0.09, "color":c,   "pos":Vector3(-0.13, 0.28, 0)},
		{"type":"bone",  "length":0.38, "radius":0.09, "color":c,   "pos":Vector3( 0.13, 0.28, 0)},
		# knee joints
		{"type":"joint", "radius":0.085,"color":dc,    "pos":Vector3(-0.13, 0.05, 0)},
		{"type":"joint", "radius":0.085,"color":dc,    "pos":Vector3( 0.13, 0.05, 0)},
		# lower legs
		{"type":"bone",  "length":0.32, "radius":0.07, "color":dc,  "pos":Vector3(-0.13,-0.22, 0)},
		{"type":"bone",  "length":0.32, "radius":0.07, "color":dc,  "pos":Vector3( 0.13,-0.22, 0)},
	]}

static func mecha(color: Color = Color(0.28, 0.32, 0.40)) -> Dictionary:
	## RETURN_VALUE — boxy bipedal mech: armour plates + joints + thrusters
	var c  := color
	var ac := Color(0.8, 0.4, 0.1)   # accent (orange glow)
	return { "parts": [
		# torso panel (front)
		{"type":"panel",    "size":Vector3(0.55, 0.65, 0.14), "color":c,   "pos":Vector3(0, 0.85, -0.07)},
		# torso panel (back)
		{"type":"panel",    "size":Vector3(0.55, 0.65, 0.14), "color":c.darkened(0.15), "pos":Vector3(0, 0.85, 0.07)},
		# chest vent strip
		{"type":"panel",    "size":Vector3(0.42, 0.08, 0.18), "color":ac,  "pos":Vector3(0, 1.05, 0)},
		# head block
		{"type":"panel",    "size":Vector3(0.30, 0.26, 0.26), "color":c.lightened(0.1), "pos":Vector3(0, 1.40, 0)},
		# visor
		{"type":"panel",    "size":Vector3(0.22, 0.08, 0.06), "color":ac.lightened(0.3), "pos":Vector3(0, 1.43,-0.14)},
		# shoulder armour L
		{"type":"panel",    "size":Vector3(0.18, 0.24, 0.22), "color":c.lightened(0.05), "pos":Vector3(-0.38, 1.12, 0)},
		# shoulder armour R
		{"type":"panel",    "size":Vector3(0.18, 0.24, 0.22), "color":c.lightened(0.05), "pos":Vector3( 0.38, 1.12, 0)},
		# upper arm joints
		{"type":"joint",    "radius":0.09, "color":c.darkened(0.2), "pos":Vector3(-0.35, 0.92, 0)},
		{"type":"joint",    "radius":0.09, "color":c.darkened(0.2), "pos":Vector3( 0.35, 0.92, 0)},
		# forearm panels
		{"type":"panel",    "size":Vector3(0.13, 0.30, 0.13), "color":c,   "pos":Vector3(-0.38, 0.68, 0)},
		{"type":"panel",    "size":Vector3(0.13, 0.30, 0.13), "color":c,   "pos":Vector3( 0.38, 0.68, 0)},
		# pelvis/hip block
		{"type":"panel",    "size":Vector3(0.48, 0.14, 0.22), "color":c.darkened(0.1), "pos":Vector3(0, 0.48, 0)},
		# thigh panels
		{"type":"panel",    "size":Vector3(0.18, 0.36, 0.18), "color":c,   "pos":Vector3(-0.16, 0.24, 0)},
		{"type":"panel",    "size":Vector3(0.18, 0.36, 0.18), "color":c,   "pos":Vector3( 0.16, 0.24, 0)},
		# knee joints
		{"type":"joint",    "radius":0.10, "color":c.darkened(0.3), "pos":Vector3(-0.16, 0.02, 0)},
		{"type":"joint",    "radius":0.10, "color":c.darkened(0.3), "pos":Vector3( 0.16, 0.02, 0)},
		# shin panels
		{"type":"panel",    "size":Vector3(0.16, 0.32, 0.16), "color":c.lightened(0.05), "pos":Vector3(-0.16,-0.22, 0)},
		{"type":"panel",    "size":Vector3(0.16, 0.32, 0.16), "color":c.lightened(0.05), "pos":Vector3( 0.16,-0.22, 0)},
		# back thrusters
		{"type":"thruster", "radius":0.10, "depth":0.18, "color":ac, "pos":Vector3(-0.18, 0.95, 0.16), "rot":Vector3(-90,0,0)},
		{"type":"thruster", "radius":0.10, "depth":0.18, "color":ac, "pos":Vector3( 0.18, 0.95, 0.16), "rot":Vector3(-90,0,0)},
	]}

static func scout_ship(color: Color = Color(0.18, 0.22, 0.32)) -> Dictionary:
	## RETURN_VALUE — small saucer scout: hull panels + cockpit + engine bells + wing edges
	var c  := color
	var gc := Color(0.3, 0.8, 1.0)   # cockpit glass
	var ec := Color(0.9, 0.5, 0.1)   # engine glow
	return { "parts": [
		# main hull disc (flat cylinder approximated with 3 stacked panels)
		{"type":"panel",    "size":Vector3(1.6, 0.12, 1.2), "color":c,                "pos":Vector3(0, 0.06, 0)},
		{"type":"panel",    "size":Vector3(1.4, 0.10, 1.0), "color":c.lightened(0.05),"pos":Vector3(0, 0.17, 0)},
		{"type":"panel",    "size":Vector3(1.1, 0.10, 0.85),"color":c.lightened(0.1), "pos":Vector3(0, 0.27, 0)},
		# cockpit bubble
		{"type":"joint",    "radius":0.26, "color":gc,      "pos":Vector3(0, 0.46, -0.12)},
		# cockpit glow
		{"type":"eye",      "radius":0.14, "color":gc,      "pos":Vector3(0, 0.42, -0.22)},
		# left engine
		{"type":"thruster", "radius":0.14, "depth":0.24, "color":ec, "pos":Vector3(-0.62, 0.0, 0.18), "rot":Vector3(90,0,0)},
		# right engine
		{"type":"thruster", "radius":0.14, "depth":0.24, "color":ec, "pos":Vector3( 0.62, 0.0, 0.18), "rot":Vector3(90,0,0)},
		# wing edges (left)
		{"type":"edge",     "from":Vector3(-0.5, 0.06,-0.4), "to":Vector3(-0.75, 0.06, 0.3), "radius":0.025, "color":c.lightened(0.2)},
		{"type":"edge",     "from":Vector3(-0.5, 0.06, 0.3), "to":Vector3(-0.75, 0.06,-0.2), "radius":0.025, "color":c.lightened(0.2)},
		# wing edges (right)
		{"type":"edge",     "from":Vector3( 0.5, 0.06,-0.4), "to":Vector3( 0.75, 0.06, 0.3), "radius":0.025, "color":c.lightened(0.2)},
		{"type":"edge",     "from":Vector3( 0.5, 0.06, 0.3), "to":Vector3( 0.75, 0.06,-0.2), "radius":0.025, "color":c.lightened(0.2)},
		# nav lights
		{"type":"eye",      "radius":0.04, "color":Color(1,0.1,0.1), "pos":Vector3(-0.78, 0.06, 0)},
		{"type":"eye",      "radius":0.04, "color":Color(0.1,1,0.1), "pos":Vector3( 0.78, 0.06, 0)},
	]}
