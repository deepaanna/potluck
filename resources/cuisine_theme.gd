## Lightweight cuisine-specific color overrides for theming.
## The actual Godot Theme is built programmatically by UIManager.
class_name CuisineTheme
extends Resource

@export var theme_name: String = ""
@export var accent_color: Color = Color(0.3, 0.5, 1.0)
@export var accent_hover: Color = Color(0.4, 0.6, 1.0)
@export var accent_pressed: Color = Color(0.2, 0.35, 0.8)
@export var panel_bg: Color = Color(0.15, 0.15, 0.2)
@export var panel_border: Color = Color(0.25, 0.25, 0.35)
@export var pot_tint: Color = Color.WHITE
@export var label_shadow_color: Color = Color(0, 0, 0, 0.5)
@export var label_outline_color: Color = Color(0, 0, 0, 0.6)
@export var button_glow_color: Color = Color(1, 1, 1, 0.3)
@export var glossy: bool = false
