extends Node2D

@onready var name_edit = $UI/RightPanel/VBoxContainer/NameEdit
@onready var body_sprite = $CharacterPreview/Body
@onready var hair_sprite = $CharacterPreview/Hair
@onready var outfit_sprite = $CharacterPreview/Outfit
@onready var accessory_sprite = $CharacterPreview/Accessory

var player_name = ""

# Current indices
var body_index = 0
var body_color_index = 0
var hair_index = 0
var hair_color_index = 0
var outfit_index = 0
var outfit_color_index = 0
var accessory_index = 0
var accessory_color_index = 0

# Keys arrays
var body_keys = []
var hair_keys = []
var outfit_keys = []
var accessory_keys = []

func _ready():
	# Initialize keys
	body_keys = Global.bodies_collection.keys()
	hair_keys = Global.hair_collection.keys()
	outfit_keys = Global.outfit_collection.keys()
	accessory_keys = Global.accessory_collection.keys()

	# Set initial appearance
	update_body()
	update_hair()
	update_outfit()
	update_accessory()

func update_body():
	var key = body_keys[body_index]
	body_sprite.texture = Global.bodies_collection[key]
	body_sprite.modulate = Global.body_color_options[body_color_index]
	Global.selected_body = key
	Global.selected_body_color = Global.body_color_options[body_color_index]

func update_hair():
	var key = hair_keys[hair_index]
	if key == "none":
		hair_sprite.texture = null
	else:
		hair_sprite.texture = Global.hair_collection[key]
		hair_sprite.modulate = Global.hair_color_options[hair_color_index]
	Global.selected_hair = key
	Global.selected_hair_color = Global.hair_color_options[hair_color_index]

func update_outfit():
	var key = outfit_keys[outfit_index]
	outfit_sprite.texture = Global.outfit_collection[key]
	outfit_sprite.modulate = Global.color_options[outfit_color_index]
	Global.selected_outfit = key
	Global.selected_outfit_color = Global.color_options[outfit_color_index]

func update_accessory():
	var key = accessory_keys[accessory_index]
	if key == "none":
		accessory_sprite.texture = null
	else:
		accessory_sprite.texture = Global.accessory_collection[key]
		accessory_sprite.modulate = Global.color_options[accessory_color_index]
	Global.selected_accessory = key
	Global.selected_accessory_color = Global.color_options[accessory_color_index]

# Button handlers
func _on_body_type_pressed():
	body_index = (body_index + 1) % body_keys.size()
	update_body()

func _on_skin_pressed():
	body_color_index = (body_color_index + 1) % Global.body_color_options.size()
	update_body()

func _on_hair_style_pressed():
	hair_index = (hair_index + 1) % hair_keys.size()
	update_hair()

func _on_hair_color_pressed():
	hair_color_index = (hair_color_index + 1) % Global.hair_color_options.size()
	update_hair()

func _on_outfit_style_pressed():
	outfit_index = (outfit_index + 1) % outfit_keys.size()
	update_outfit()

func _on_outfit_color_pressed():
	outfit_color_index = (outfit_color_index + 1) % Global.color_options.size()
	update_outfit()

func _on_accessory_style_pressed():
	accessory_index = (accessory_index + 1) % accessory_keys.size()
	update_accessory()

func _on_accessory_color_pressed():
	accessory_color_index = (accessory_color_index + 1) % Global.color_options.size()
	update_accessory()

func _on_name_edit_text_changed(new_text):
	player_name = new_text

func _on_confirm_button_pressed():
	if player_name.strip_edges() != "":
		Global.player_name = player_name
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
