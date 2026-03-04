## Data class for a combo (two-ingredient pairing).
class_name ComboData
extends RefCounted

var combo_name: String
var ingredient_a: String
var ingredient_b: String
var multiplier: float
var bonus_heat: float
var is_penalty: bool


static func create(p_name: String, p_a: String, p_b: String, p_multiplier: float, p_bonus_heat: float = 0.0) -> ComboData:
	var data: ComboData = ComboData.new()
	data.combo_name = p_name
	data.ingredient_a = p_a
	data.ingredient_b = p_b
	data.multiplier = p_multiplier
	data.bonus_heat = p_bonus_heat
	data.is_penalty = p_multiplier < 1.0
	return data


func matches(ids: Array[String]) -> bool:
	return ingredient_a in ids and ingredient_b in ids
