## Data class for a single ingredient.
class_name IngredientData
extends RefCounted

enum Rarity { COMMON, UNCOMMON, RARE }
enum Cuisine { BASIC, ITALIAN, JAPANESE }

var id: String
var display_name: String
var points: int
var heat: float
var rarity: Rarity
var cuisine: Cuisine
var color: Color
var sprite_index: int = 0


static func create(p_id: String, p_name: String, p_points: int, p_heat: float, p_rarity: Rarity, p_cuisine: Cuisine, p_color: Color) -> IngredientData:
	var data: IngredientData = IngredientData.new()
	data.id = p_id
	data.display_name = p_name
	data.points = p_points
	data.heat = p_heat
	data.rarity = p_rarity
	data.cuisine = p_cuisine
	data.color = p_color
	return data
