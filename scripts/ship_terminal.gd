extends CanvasLayer
## ShipTerminal — in-ship computer terminal, toggle with ` (tilde)
## TREE_STRUCTURE — CanvasLayer > Panel > VBoxContainer > output Label + input LineEdit
## Commands: help  status  aliens  time  credits N  seed  quit
##
## Reads from GameState for live data.
## "update the universe as you play"

var _panel:  PanelContainer
var _output: RichTextLabel
var _input:  LineEdit
var _history: Array[String] = []
var _visible_flag: bool = false
var _refresh_timer: float = 0.0

const MAX_LINES := 18
const BLINK_SEC := 0.5
var _blink_t: float = 0.0
var _cursor_on: bool = true

func _ready() -> void:
	layer = 20
	_build_ui()
	_push("FRONTIER SHIP COMPUTER  v1.0")
	_push("────────────────────────────")
	_push("press ` to toggle  |  type 'help'")
	_push("")
	visible = false

func _build_ui() -> void:
	## TREE_STRUCTURE — dark terminal panel, top-right corner
	_panel = PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color          = Color(0.0, 0.04, 0.0, 0.92)
	ps.border_color      = Color(0.0, 0.7, 0.2, 0.8)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", ps)
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.size = Vector2(420, 320)
	_panel.position = Vector2(-432, 12)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	_output = RichTextLabel.new()
	_output.bbcode_enabled   = true
	_output.scroll_following = true
	_output.custom_minimum_size = Vector2(0, 265)
	_output.add_theme_font_size_override("normal_font_size", 11)
	_output.add_theme_color_override("default_color", Color(0.0, 0.9, 0.3))
	vbox.add_child(_output)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.0, 0.5, 0.2, 0.6))
	vbox.add_child(sep)

	_input = LineEdit.new()
	_input.placeholder_text = "> _"
	_input.add_theme_font_size_override("font_size", 11)
	_input.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	_input.add_theme_color_override("font_placeholder_color", Color(0.0, 0.6, 0.2, 0.6))
	var ins := StyleBoxFlat.new()
	ins.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_input.add_theme_stylebox_override("normal", ins)
	_input.add_theme_stylebox_override("focus", ins)
	_input.text_submitted.connect(_on_submit)
	vbox.add_child(_input)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var ke := event as InputEventKey
	if ke.pressed and (ke.keycode == KEY_QUOTELEFT or ke.keycode == KEY_SECTION):
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	_visible_flag = not _visible_flag
	visible = _visible_flag
	if _visible_flag:
		_refresh_status()
		_input.grab_focus()
	else:
		_input.release_focus()

func _process(delta: float) -> void:
	if not _visible_flag: return
	_refresh_timer += delta
	if _refresh_timer >= 2.0:
		_refresh_timer = 0.0
		_push_status_line()

# ── commands ───────────────────────────────────────────────────────────────

func _on_submit(text: String) -> void:
	_input.clear()
	text = text.strip_edges()
	if text.is_empty(): return
	_push("> " + text)
	_history.append(text)
	_handle(text)

func _handle(cmd: String) -> void:
	## RETURN_VALUE — parse and execute a terminal command
	var parts := cmd.to_lower().split(" ", false)
	if parts.is_empty(): return
	match parts[0]:
		"help":
			_push("commands:")
			_push("  status    — ship + economy summary")
			_push("  aliens    — registered + pending list")
			_push("  time      — current game time")
			_push("  credits N — set credits to N")
			_push("  woolongs N — set woolongs to N")
			_push("  seed      — show universe seed (TODO)")
			_push("  clear     — clear terminal")
		"status":
			_refresh_status()
		"aliens":
			_list_aliens()
		"time":
			if has_node("/root/GameState"):
				_push(get_node("/root/GameState").get_time_string())
			else:
				_push("GameState not loaded")
		"credits":
			if parts.size() >= 2 and parts[1].is_valid_int():
				if has_node("/root/GameState"):
					get_node("/root/GameState").credits = parts[1].to_int()
					get_node("/root/GameState").save_game()
					_push("credits set to " + parts[1])
				else:
					_push("GameState not loaded")
			else:
				_push("usage: credits <amount>")
		"woolongs":
			if parts.size() >= 2 and parts[1].is_valid_int():
				if has_node("/root/GameState"):
					get_node("/root/GameState").woolongs = parts[1].to_int()
					get_node("/root/GameState").save_game()
					_push("woolongs set to " + parts[1])
				else:
					_push("GameState not loaded")
			else:
				_push("usage: woolongs <amount>")
		"seed":
			_push("universe seed: FRONTIER-001  (procedural sectors: TODO)")
		"clear":
			_output.clear()
		_:
			_push("unknown: " + parts[0] + "  (type 'help')")

# ── display helpers ────────────────────────────────────────────────────────

func _refresh_status() -> void:
	## QUERY_NODE — reads GameState and pushes a status block
	_push("── STATUS ──────────────────")
	if not has_node("/root/GameState"):
		_push("  [no GameState]")
		return
	var gs := get_node("/root/GameState")
	_push("  time      " + gs.get_time_string())
	_push("  credits   " + str(gs.credits) + " ₩")
	_push("  woolongs  " + str(gs.woolongs))
	var cargo_total: int = 0
	for v in gs.cargo.values(): cargo_total += v
	_push("  cargo     " + str(cargo_total) + "/20")
	_push("  pending   " + str(gs.pending_aliens.size()) + " aliens (unregistered)")
	_push("  registered " + str(gs.registered_aliens.size()) + " total")
	_push("────────────────────────────")

func _list_aliens() -> void:
	## QUERY_NODE — lists all alien registrations
	if not has_node("/root/GameState"):
		_push("[no GameState]")
		return
	var gs := get_node("/root/GameState")
	if gs.registered_aliens.is_empty():
		_push("  no registered aliens")
	else:
		for id in gs.registered_aliens:
			_push("  [✓] " + str(id))
	if not gs.pending_aliens.is_empty():
		_push("  pending (collect at CLERK):")
		for a in gs.pending_aliens:
			_push("  [ ] " + str(a["id"]) + "  +" + str(a["woolongs"]) + " ₩")

func _push_status_line() -> void:
	## QUERY_NODE — one-line auto-refresh while terminal is open
	if not has_node("/root/GameState"): return
	var gs := get_node("/root/GameState")
	_push("[" + gs.get_time_string() + "]  ₩" + str(gs.credits) +
		"  woolongs:" + str(gs.woolongs))

func _push(line: String) -> void:
	_output.append_text(line + "\n")
