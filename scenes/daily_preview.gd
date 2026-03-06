## Daily challenge preview screen — shows today's ingredients before playing.
extends Control

@onready var _date_label: Label = %DateLabel
@onready var _best_label: Label = %BestLabel
@onready var _ingredient_grid: GridContainer = %IngredientGrid
@onready var _start_button: Button = %StartButton
@onready var _back_button: Button = %BackButton

var _daily_bag: Array[IngredientData] = []

const CELLS_PER_SHEET: int = 5
const CELL_SIZE: float = 464.0
const SHEET_PATHS: PackedStringArray = [
	"res://assets/sprites/sheet1.png",
	"res://assets/sprites/sheet2.png",
	"res://assets/sprites/sheet3.png",
	"res://assets/sprites/sheet4.png",
	"res://assets/sprites/sheet5.png",
]


func _ready() -> void:
	AnalyticsManager.log_screen("daily_preview")

	_start_button.pressed.connect(_on_start)
	_back_button.pressed.connect(_on_back)

	# Date display
	var date: Dictionary = Time.get_date_dict_from_system()
	_date_label.text = "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]

	# Best score
	if DailyChallenge.is_completed_today():
		var best: int = DailyChallenge.get_today_best()
		_best_label.text = "Your Best: %s" % Utils.format_number(best)
		_start_button.text = "Try Again"
	else:
		_best_label.text = "Not yet attempted"
		_start_button.text = "Start Challenge"

	# Build ingredient preview
	_daily_bag = DailyChallenge.get_daily_bag()
	_build_ingredient_list()
	_play_entrance_animations()


func _build_ingredient_list() -> void:
	for ingredient: IngredientData in _daily_bag:
		var card: PanelContainer = _create_ingredient_card(ingredient)
		_ingredient_grid.add_child(card)


func _create_ingredient_card(data: IngredientData) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 90)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	# Rounded color swatch
	var swatch_panel: PanelContainer = PanelContainer.new()
	swatch_panel.custom_minimum_size = Vector2(50, 50)
	var swatch_sb := StyleBoxFlat.new()
	swatch_sb.bg_color = data.color
	swatch_sb.set_corner_radius_all(8)
	swatch_panel.add_theme_stylebox_override("panel", swatch_sb)
	hbox.add_child(swatch_panel)

	# Sprite thumbnail
	var thumb := _load_sprite_thumbnail(data)
	if thumb:
		thumb.custom_minimum_size = Vector2(40, 40)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(thumb)

	# Name + points
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_label: Label = Label.new()
	name_label.text = data.display_name
	name_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(name_label)

	var points_label: Label = Label.new()
	points_label.text = "+%d pts  | heat %.0f%%" % [data.points, data.heat * 100.0]
	points_label.add_theme_font_size_override("font_size", 24)
	points_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(points_label)

	return panel


func _load_sprite_thumbnail(data: IngredientData) -> TextureRect:
	var idx: int = data.sprite_index
	var sheet_num: int = idx / CELLS_PER_SHEET
	var col: int = idx % CELLS_PER_SHEET

	if sheet_num >= SHEET_PATHS.size():
		return null

	var texture: Texture2D = load(SHEET_PATHS[sheet_num]) as Texture2D
	if texture == null:
		return null

	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(col * CELL_SIZE, 0, CELL_SIZE, CELL_SIZE)

	var tex_rect := TextureRect.new()
	tex_rect.texture = atlas
	return tex_rect


func _play_entrance_animations() -> void:
	# Title + date fade in
	var title: Label = $SafeArea/VBox/TitleLabel
	title.modulate.a = 0.0
	_date_label.modulate.a = 0.0
	var title_tween := create_tween().set_parallel(true)
	title_tween.tween_property(title, "modulate:a", 1.0, 0.2)
	title_tween.tween_property(_date_label, "modulate:a", 1.0, 0.2)

	# Cards stagger pop_in
	var cards := _ingredient_grid.get_children()
	for i in cards.size():
		Juice.pop_in(cards[i], 0.3, 0.05 * i)

	# Buttons pop in after last card
	var btn_delay: float = 0.05 * cards.size() + 0.15
	Juice.pop_in(_start_button, 0.3, btn_delay)
	Juice.pop_in(_back_button, 0.3, btn_delay + 0.08)


func _on_start() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "daily_start"})
	GameManager.set_meta("game_mode", "daily")
	GameManager.goto_scene("res://scenes/game_scene.tscn")


func _on_back() -> void:
	AnalyticsManager.log_event("button_clicked", {"button": "daily_back"})
	GameManager.goto_scene("res://scenes/main_menu.tscn")
