extends Node2D

@onready var hair_sprite = $Sprite2D

var hair_keys = []
var current_hair_index = 0
var current_color_index = 0

func _ready():
	set_sprite_keys()
	update_sprite()

func set_sprite_keys():
	hair_keys = Global.hair_collection.keys()

func update_sprite():
	var current_sprite = hair_keys[current_hair_index]
	if current_sprite == "none":
		hair_sprite.texture = null
	else:
		hair_sprite.texture = Global.hair_collection[current_sprite]
		hair_sprite.hframes = 8
		hair_sprite.vframes = 8
		hair_sprite.frame = 0
		hair_sprite.modulate = Global.hair_color_options[current_color_index]

	Global.selected_hair = current_sprite
	Global.selected_hair_color = Global.hair_color_options[current_color_index]

func _on_collection_button_pressed():
	current_hair_index = (current_hair_index + 1) % hair_keys.size()
	update_sprite()

func _on_color_button_pressed():
	current_color_index = (current_color_index + 1) % Global.hair_color_options.size()
	update_sprite()
