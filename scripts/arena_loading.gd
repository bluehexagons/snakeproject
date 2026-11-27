extends CanvasLayer

const ARENA_PATH = "res://scenes/main.tscn"
const MIN_VISIBLE_MSEC = 320

@onready var screen: Control = $Screen
@onready var status_label: Label = $Screen/Center/Panel/Content/Status
@onready var activity: Control = $Screen/Center/Panel/Content/Activity
@onready var back_button: Button = $Screen/Center/Panel/Content/Back

var previous_focus: Control
var was_paused := false
var lost_focus := false

func _ready() -> void:
	back_button.pressed.connect(_dismiss_error)
	set_process_input(false)

func open_arena(resume: bool) -> void:
	if screen.visible:
		return

	var tree := get_tree()
	was_paused = tree.paused
	lost_focus = false
	previous_focus = get_viewport().gui_get_focus_owner()
	if is_instance_valid(previous_focus):
		previous_focus.release_focus()
	tree.paused = true
	set_process_input(true)
	status_label.text = "Restoring your run…" if resume else "Preparing the arena…"
	back_button.hide()
	activity.show()
	screen.show()
	SoundFx.play(SoundFx.Cue.UI, 0.53, 1.12 if resume else 1.27)

	var shown_at := Time.get_ticks_msec()
	# Give the loading screen a frame before the single-threaded Web load.
	await tree.process_frame
	await tree.process_frame
	var arena := await _load_arena()
	var remaining_msec := MIN_VISIBLE_MSEC - (Time.get_ticks_msec() - shown_at)
	if remaining_msec > 0:
		await tree.create_timer(remaining_msec / 1000.0, true, false, true).timeout

	if arena == null:
		_show_error("Couldn't load the arena.")
		return
	if not resume and not GameState.delete_save_game():
		_show_error("Couldn't clear the saved run.")
		return
	if tree.change_scene_to_packed(arena) != OK:
		_show_error("Couldn't open the arena.")
		return

	await tree.scene_changed
	_close_screen(false)
	previous_focus = null
	if lost_focus and tree.current_scene:
		tree.current_scene.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)

func _load_arena() -> PackedScene:
	if OS.has_feature("web"):
		return ResourceLoader.load(ARENA_PATH, "PackedScene") as PackedScene
	if ResourceLoader.load_threaded_request(ARENA_PATH, "PackedScene") != OK:
		return null
	var status := ResourceLoader.load_threaded_get_status(ARENA_PATH)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(ARENA_PATH)
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return null
	return ResourceLoader.load_threaded_get(ARENA_PATH) as PackedScene

func _show_error(message: String) -> void:
	status_label.text = message
	activity.hide()
	back_button.show()
	back_button.grab_focus()

func _dismiss_error() -> void:
	_close_screen(was_paused)
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()
	previous_focus = null

func _close_screen(paused: bool) -> void:
	screen.hide()
	set_process_input(false)
	get_tree().paused = paused

func _input(event: InputEvent) -> void:
	if not back_button.visible:
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss_error()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and screen.visible:
		lost_focus = true
