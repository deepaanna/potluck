## Central UI management — screen transitions, popup/overlay layer control.
## Creates CanvasLayers for overlays (10), popups (20), and transitions (100).
extends Node

signal transition_started
signal transition_finished
signal theme_changed(cuisine_name: String)

enum Transition { NONE, FADE }

var _overlay_layer: CanvasLayer
var _popup_layer: CanvasLayer
var _transition_layer: CanvasLayer
var _transition_rect: ColorRect
var _transitioning: bool = false
var _active_popups: Array[BasePopup] = []
var _active_overlays: Dictionary = {}  # name -> BaseOverlay

# Cuisine theme system
var _current_cuisine_theme: CuisineTheme = null
var _base_theme: Theme = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_layers()
	_base_theme = load("res://themes/default_theme.tres") as Theme
	_hook_button_glow()
	# Fade in from black on initial load
	_transition_rect.modulate.a = 1.0
	get_tree().process_frame.connect(_initial_fade_in, CONNECT_ONE_SHOT)


## Change the current screen with an optional transition
func change_screen(path: String, transition: Transition = Transition.FADE, duration: float = 0.5) -> void:
	if _transitioning:
		push_warning("UIManager: Transition already in progress, ignoring change_screen")
		return

	dismiss_all_popups()

	match transition:
		Transition.NONE:
			_change_scene_immediate(path)
		Transition.FADE:
			await _fade_transition(path, duration)


## Check if a screen transition is currently in progress
func is_transitioning() -> bool:
	return _transitioning


## Show a popup on the popup layer
func show_popup(scene: PackedScene, data: Dictionary = {}) -> BasePopup:
	var instance: BasePopup = scene.instantiate() as BasePopup
	if instance == null:
		push_error("UIManager: Scene is not a BasePopup")
		return null
	instance._popup_data = data
	_popup_layer.add_child(instance)
	_active_popups.append(instance)
	instance.animate_in()
	instance._on_popup_opened()
	return instance


## Dismiss a specific popup with animation
func dismiss_popup(popup: BasePopup) -> void:
	if popup not in _active_popups:
		return
	_active_popups.erase(popup)
	await popup.animate_out()
	if is_instance_valid(popup):
		popup.dismissed.emit()
		popup.queue_free()


## Dismiss all active popups immediately (no animation)
func dismiss_all_popups() -> void:
	var popups_copy: Array[BasePopup] = _active_popups.duplicate()
	_active_popups.clear()
	for popup: BasePopup in popups_copy:
		if is_instance_valid(popup):
			popup.dismissed.emit()
			popup.queue_free()


## Check if any popups are active
func has_popup() -> bool:
	return not _active_popups.is_empty()


## Get the number of active popups
func get_popup_count() -> int:
	return _active_popups.size()


## Show an overlay on the overlay layer
func show_overlay(scene: PackedScene, overlay_name: String) -> BaseOverlay:
	if has_overlay(overlay_name):
		push_warning("UIManager: Overlay '%s' already shown" % overlay_name)
		return _active_overlays[overlay_name] as BaseOverlay

	var instance: BaseOverlay = scene.instantiate() as BaseOverlay
	if instance == null:
		push_error("UIManager: Scene is not a BaseOverlay")
		return null
	instance._overlay_name = overlay_name
	_overlay_layer.add_child(instance)
	_active_overlays[overlay_name] = instance
	instance._on_overlay_shown()
	return instance


## Dismiss a named overlay
func dismiss_overlay(overlay_name: String) -> void:
	if not has_overlay(overlay_name):
		return
	var overlay: BaseOverlay = _active_overlays[overlay_name] as BaseOverlay
	_active_overlays.erase(overlay_name)
	if is_instance_valid(overlay):
		overlay._on_overlay_hidden()
		overlay.queue_free()


## Check if a named overlay is active
func has_overlay(overlay_name: String) -> bool:
	return overlay_name in _active_overlays


func _setup_layers() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 10
	_overlay_layer.name = "OverlayLayer"
	add_child(_overlay_layer)

	_popup_layer = CanvasLayer.new()
	_popup_layer.layer = 20
	_popup_layer.name = "PopupLayer"
	add_child(_popup_layer)

	_transition_layer = CanvasLayer.new()
	_transition_layer.layer = 100
	_transition_layer.name = "TransitionLayer"
	add_child(_transition_layer)

	_transition_rect = ColorRect.new()
	_transition_rect.color = Color(0.02, 0.02, 0.04)
	_transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_rect.modulate.a = 0.0
	_transition_layer.add_child(_transition_rect)


func _initial_fade_in() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_transition_rect, "modulate:a", 0.0, 0.3)


func _change_scene_immediate(path: String) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene is BaseScreen:
		(current_scene as BaseScreen)._on_screen_exit()

	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("UIManager: Failed to change scene to %s: %s" % [path, error_string(error)])


func _fade_transition(path: String, duration: float) -> void:
	_transitioning = true
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_started.emit()

	var half_duration: float = duration / 2.0

	# Fade to black
	var tween: Tween = create_tween()
	tween.tween_property(_transition_rect, "modulate:a", 1.0, half_duration)
	await tween.finished

	# Change scene
	_change_scene_immediate(path)

	# Wait one frame for scene to initialize
	await get_tree().process_frame

	# Fade from black
	var tween_out: Tween = create_tween()
	tween_out.tween_property(_transition_rect, "modulate:a", 0.0, half_duration)
	await tween_out.finished

	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false
	transition_finished.emit()


# ── Cuisine Theme System ─────────────────────────────────────────────────

## Returns the highest unlocked cuisine name for theming
func get_active_cuisine_name() -> String:
	var unlocked: Array = SaveManager.get_value("pot_luck.unlocked_cuisines", ["basic"]) as Array
	if "japanese" in unlocked:
		return "japanese"
	if "italian" in unlocked:
		return "italian"
	return "basic"


## Load and apply a cuisine theme by name
func swap_cuisine_theme(cuisine_name: String) -> void:
	var path: String = "res://themes/cuisine_%s.tres" % cuisine_name
	if not ResourceLoader.exists(path):
		push_warning("UIManager: Cuisine theme not found: %s" % path)
		return

	var ct: CuisineTheme = load(path) as CuisineTheme
	if ct == null:
		push_warning("UIManager: Failed to load cuisine theme: %s" % path)
		return

	_current_cuisine_theme = ct
	var built_theme: Theme = _build_theme(_base_theme, ct)
	get_tree().root.theme = built_theme
	theme_changed.emit(cuisine_name)


## Returns the current cuisine theme resource
func get_cuisine_theme() -> CuisineTheme:
	return _current_cuisine_theme


func _build_theme(base: Theme, ct: CuisineTheme) -> Theme:
	var t: Theme = base.duplicate() as Theme

	# Override Button normal/hover/pressed styles with cuisine accent colors
	for style_name: String in ["normal", "hover", "pressed"]:
		var existing: StyleBox = t.get_stylebox(style_name, "Button")
		if existing is StyleBoxFlat:
			var sb: StyleBoxFlat = (existing as StyleBoxFlat).duplicate() as StyleBoxFlat
			match style_name:
				"normal":
					sb.bg_color = ct.accent_color.darkened(0.5)
					sb.border_color = ct.accent_color.darkened(0.2)
				"hover":
					sb.bg_color = ct.accent_hover.darkened(0.4)
					sb.border_color = ct.accent_hover
				"pressed":
					sb.bg_color = ct.accent_pressed.darkened(0.5)
					sb.border_color = ct.accent_pressed.darkened(0.15)

			# Glossy effect: brighter top border
			if ct.glossy:
				sb.border_width_top = 4
				sb.border_color = sb.border_color.lightened(0.3)

			t.set_stylebox(style_name, "Button", sb)

	# Panel styling
	var panel_sb: StyleBox = t.get_stylebox("panel", "PanelContainer")
	if panel_sb is StyleBoxFlat:
		var sb: StyleBoxFlat = (panel_sb as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.bg_color = ct.panel_bg
		sb.border_color = ct.panel_border
		t.set_stylebox("panel", "PanelContainer", sb)

	# Label cartoon styling via theme constants/colors
	t.set_color("font_shadow_color", "Label", ct.label_shadow_color)
	t.set_constant("shadow_offset_x", "Label", 2)
	t.set_constant("shadow_offset_y", "Label", 3)
	t.set_constant("outline_size", "Label", 3)
	t.set_color("font_outline_color", "Label", ct.label_outline_color)

	return t


# ── Button Glow Hook ─────────────────────────────────────────────────────

func _hook_button_glow() -> void:
	get_tree().node_added.connect(_on_node_added_for_glow)


func _on_node_added_for_glow(node: Node) -> void:
	if node is Button:
		var button: Button = node as Button
		button.button_down.connect(_on_button_glow.bind(button))


func _on_button_glow(button: Button) -> void:
	var glow_color: Color = Color(1, 1, 1, 0.3)
	if _current_cuisine_theme != null:
		glow_color = _current_cuisine_theme.button_glow_color
	Juice.button_press_glow(button, glow_color)
