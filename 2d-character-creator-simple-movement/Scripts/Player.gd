extends CharacterBody2D

# Node references
@onready var body = $Skeleton/Body
@onready var hair = $Skeleton/Hair
@onready var outfit = $Skeleton/Outfit
@onready var accessory = $Skeleton/Accessory
@onready var name_label = $Skeleton/NameLabel
@onready var animation_player = $AnimationPlayer

var last_direction = Vector2.DOWN
const SPEED = 200

func _ready():
	initialize_player()

func _physics_process(_delta):
	var direction = Vector2.ZERO
	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")

	# Store the last direction for idle animation
	if direction != Vector2.ZERO:
		last_direction = direction

	# Update velocity
	velocity = direction.normalized() * SPEED

	# Play animations based on movement
	if direction != Vector2.ZERO:
		if abs(direction.x) > abs(direction.y):
			if direction.x < 0:
				animation_player.play("walk_left")
			else:
				animation_player.play("walk_right")
		else:
			if direction.y < 0:
				animation_player.play("walk_up")
			else:
				animation_player.play("walk_down")
	else:
		# Idle animations based on last direction
		if abs(last_direction.x) > abs(last_direction.y):
			if last_direction.x < 0:
				animation_player.play("idle_left")
			else:
				animation_player.play("idle_right")
		else:
			if last_direction.y < 0:
				animation_player.play("idle_up")
			else:
				animation_player.play("idle_down")

	move_and_slide()

func initialize_player():
	# Body and color
	body.texture = Global.bodies_collection[Global.selected_body]
	body.hframes = 8
	body.vframes = 8
	body.modulate = Global.selected_body_color

	# Hair and color
	if Global.selected_hair != "none":
		hair.texture = Global.hair_collection[Global.selected_hair]
		hair.hframes = 8
		hair.vframes = 8
		hair.modulate = Global.selected_hair_color
	else:
		hair.texture = null

	# Outfit and color
	outfit.texture = Global.outfit_collection[Global.selected_outfit]
	outfit.hframes = 8
	outfit.vframes = 8
	outfit.modulate = Global.selected_outfit_color

	# Accessory and color
	if Global.selected_accessory != "none":
		accessory.texture = Global.accessory_collection[Global.selected_accessory]
		accessory.hframes = 8
		accessory.vframes = 8
		accessory.modulate = Global.selected_accessory_color
	else:
		accessory.texture = null

	# Player name
	name_label.text = Global.player_name
