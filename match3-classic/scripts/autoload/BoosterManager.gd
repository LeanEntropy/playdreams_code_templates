extends Node
class_name BoosterManagerClass
## Manages booster inventory and activation state

signal booster_activated(booster_type: Enums.BoosterType)
signal booster_used(booster_type: Enums.BoosterType)
signal booster_cancelled()
signal inventory_changed()

var active_booster: Enums.BoosterType = Enums.BoosterType.NONE
var inventory: Dictionary = {}

func _ready() -> void:
	_initialize_inventory()

func _initialize_inventory() -> void:
	inventory = {
		Enums.BoosterType.LOLLIPOP_HAMMER: ConfigManager.get_starting_boosters("lollipop_hammer"),
		Enums.BoosterType.FREE_SWITCH: ConfigManager.get_starting_boosters("free_switch"),
		Enums.BoosterType.SHUFFLE: ConfigManager.get_starting_boosters("shuffle"),
		Enums.BoosterType.COLOR_BOMB_START: ConfigManager.get_starting_boosters("color_bomb_start"),
		Enums.BoosterType.EXTRA_MOVES: ConfigManager.get_starting_boosters("extra_moves"),
	}
	inventory_changed.emit()

func reset_inventory() -> void:
	_initialize_inventory()

func get_count(booster_type: Enums.BoosterType) -> int:
	return inventory.get(booster_type, 0)

func has_booster(booster_type: Enums.BoosterType) -> bool:
	return get_count(booster_type) > 0

func add_booster(booster_type: Enums.BoosterType, amount: int = 1) -> void:
	inventory[booster_type] = get_count(booster_type) + amount
	inventory_changed.emit()

func activate_booster(booster_type: Enums.BoosterType) -> bool:
	if not ConfigManager.is_booster_enabled(booster_type):
		return false
	if not has_booster(booster_type):
		return false
	if active_booster != Enums.BoosterType.NONE:
		return false

	active_booster = booster_type
	booster_activated.emit(booster_type)
	return true

func use_booster() -> void:
	if active_booster == Enums.BoosterType.NONE:
		return

	inventory[active_booster] = max(0, get_count(active_booster) - 1)
	var used_type := active_booster
	active_booster = Enums.BoosterType.NONE
	booster_used.emit(used_type)
	inventory_changed.emit()

func cancel_booster() -> void:
	if active_booster != Enums.BoosterType.NONE:
		active_booster = Enums.BoosterType.NONE
		booster_cancelled.emit()

func is_booster_active() -> bool:
	return active_booster != Enums.BoosterType.NONE

func get_active_booster() -> Enums.BoosterType:
	return active_booster

func is_instant_booster(booster_type: Enums.BoosterType) -> bool:
	return booster_type in [Enums.BoosterType.SHUFFLE, Enums.BoosterType.EXTRA_MOVES]

func booster_to_string(booster_type: Enums.BoosterType) -> String:
	match booster_type:
		Enums.BoosterType.LOLLIPOP_HAMMER: return "Hammer"
		Enums.BoosterType.FREE_SWITCH: return "Free Switch"
		Enums.BoosterType.SHUFFLE: return "Shuffle"
		Enums.BoosterType.COLOR_BOMB_START: return "Color Bomb"
		Enums.BoosterType.EXTRA_MOVES: return "+5 Moves"
		_: return "None"
