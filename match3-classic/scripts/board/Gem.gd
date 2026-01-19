extends Area2D
class_name Gem
## Individual gem piece for the match-3 board

signal clicked(gem: Gem)
signal swiped(gem: Gem, direction: Vector2)

var gem_color: Enums.GemColor = Enums.GemColor.NONE
var special_type: Enums.SpecialType = Enums.SpecialType.NONE
var grid_position: Vector2i = Vector2i.ZERO
var is_falling: bool = false
var is_selected: bool = false
var _tile_scale: float = 1.0
var _sprite_scale: float = 1.0  # Actual sprite scale after texture size adjustment

var _swipe_start_pos: Vector2 = Vector2.ZERO
var _touch_started: bool = false
const SWIPE_THRESHOLD := 30.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var special_overlay: Sprite2D = $SpecialOverlay
@onready var selection_ring: Sprite2D = $SelectionRing

func _ready() -> void:
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	if selection_ring:
		selection_ring.visible = false
	if special_overlay:
		special_overlay.visible = false

	call_deferred("_update_visual")

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return

	if event.pressed:
		var local_pos := to_local(event.global_position)
		if _get_click_rect().has_point(local_pos):
			_swipe_start_pos = event.global_position
			_touch_started = true
	elif _touch_started:
		var swipe_vector: Vector2 = event.global_position - _swipe_start_pos
		if swipe_vector.length() >= SWIPE_THRESHOLD:
			swiped.emit(self, _get_swipe_direction(swipe_vector))
		else:
			_handle_click()
		_touch_started = false

func setup(color: Enums.GemColor, pos: Vector2i, scale_factor: float = 1.0) -> void:
	gem_color = color
	grid_position = pos
	_tile_scale = scale_factor
	special_type = Enums.SpecialType.NONE
	_update_visual()

func set_special(type: Enums.SpecialType) -> void:
	special_type = type
	_update_special_overlay()

func animate_special_creation() -> Tween:
	if not _can_animate() or not sprite:
		return null
	SoundManager.play_special()
	var tween := create_tween()
	# Flash bright and scale up, then settle back
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate", Color(2.5, 2.5, 2.5), 0.08)
	tween.tween_property(sprite, "scale", Vector2(_sprite_scale * 1.4, _sprite_scale * 1.4), 0.08).set_ease(Tween.EASE_OUT)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	tween.tween_property(sprite, "scale", Vector2(_sprite_scale, _sprite_scale), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tween

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_ring:
		selection_ring.visible = selected
		if selected:
			_animate_selection_ring()

func is_color_bomb() -> bool:
	return special_type == Enums.SpecialType.COLOR_BOMB

func is_special() -> bool:
	return special_type != Enums.SpecialType.NONE

func matches_color(other_color: Enums.GemColor) -> bool:
	return is_color_bomb() or gem_color == other_color

func _can_animate() -> bool:
	return not is_queued_for_deletion() and is_inside_tree()

func animate_to_position(target_pos: Vector2, duration: float = ConfigManager.get_drop_duration()) -> Tween:
	if not _can_animate():
		return null
	is_falling = true
	var tween := create_tween()
	tween.tween_property(self, "position", target_pos, duration).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): is_falling = false)
	return tween

func animate_swap_to(target_pos: Vector2, duration: float = ConfigManager.get_swap_duration()) -> Tween:
	if not _can_animate():
		return null
	var tween := create_tween()
	tween.tween_property(self, "position", target_pos, duration).set_ease(Tween.EASE_IN_OUT)
	return tween

func animate_destroy() -> Tween:
	if not _can_animate():
		return null
	var tween := create_tween()
	tween.set_parallel(true)
	var duration := ConfigManager.get_explode_duration()
	if sprite:
		tween.tween_property(sprite, "scale", Vector2.ZERO, duration)
		tween.tween_property(sprite, "rotation", TAU, duration)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	return tween

func animate_spawn() -> Tween:
	if not _can_animate():
		return null
	if sprite:
		sprite.scale = Vector2.ZERO
	modulate = Color.WHITE
	var tween := create_tween()
	if sprite:
		tween.tween_property(sprite, "scale", Vector2(_sprite_scale, _sprite_scale), ConfigManager.get_spawn_duration()).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func(): is_falling = false)
	return tween

func animate_match_highlight() -> Tween:
	if not _can_animate() or not sprite:
		return null
	var original_modulate := sprite.modulate
	var tween := create_tween()
	var time := ConfigManager.get_match_highlight_time()
	for i in 2:
		tween.tween_property(sprite, "modulate", Color.WHITE, time)
		tween.tween_property(sprite, "modulate", original_modulate, time)
	return tween

func animate_special_activation() -> Tween:
	if not _can_animate():
		return null
	var flash_dur := ConfigManager.get_special_flash_duration()
	var shrink_dur := ConfigManager.get_special_shrink_duration()
	var tween := create_tween()
	tween.set_parallel(true)
	if sprite:
		tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0), flash_dur)
		tween.tween_property(sprite, "scale", sprite.scale * 1.3, shrink_dur)
	tween.chain()
	if sprite:
		tween.tween_property(sprite, "scale", Vector2.ZERO, shrink_dur)
		tween.tween_property(sprite, "modulate:a", 0.0, shrink_dur)
	return tween

func _update_visual() -> void:
	if not sprite:
		return

	if gem_color == Enums.GemColor.NONE:
		visible = false
		return

	visible = true

	var theme_texture := ConfigManager.get_gem_texture(gem_color)
	if theme_texture:
		sprite.texture = theme_texture
		sprite.modulate = Color.WHITE
		# Scale based on actual texture size to fit tile
		var tex_size := float(theme_texture.get_width())
		var target_size := float(ConfigManager.get_base_gem_size()) * _tile_scale
		_sprite_scale = target_size / tex_size
		sprite.scale = Vector2(_sprite_scale, _sprite_scale)
	else:
		# Use procedural metallic ring texture with color modulation
		sprite.texture = _create_circle_texture()
		sprite.modulate = ConfigManager.get_gem_fallback_color(gem_color)
		_sprite_scale = _tile_scale
		sprite.scale = Vector2(_sprite_scale, _sprite_scale)

	_update_special_overlay()

func _update_special_overlay() -> void:
	if not special_overlay:
		return

	if special_type == Enums.SpecialType.NONE:
		special_overlay.visible = false
		return

	special_overlay.visible = true
	special_overlay.scale = Vector2(_sprite_scale, _sprite_scale)

	var overlay_path := "res://assets/gems/special_%d.png" % special_type
	if ResourceLoader.exists(overlay_path):
		special_overlay.texture = load(overlay_path)
		return

	special_overlay.texture = _create_special_indicator()
	match special_type:
		Enums.SpecialType.STRIPED_H, Enums.SpecialType.STRIPED_V:
			special_overlay.modulate = Color(1.0, 1.0, 1.0, 0.7)
		Enums.SpecialType.WRAPPED:
			special_overlay.modulate = Color(1.0, 0.8, 0.2, 0.8)
		Enums.SpecialType.COLOR_BOMB:
			sprite.modulate = Color(0.2, 0.2, 0.2)
			special_overlay.modulate = Color.WHITE

func _create_circle_texture() -> ImageTexture:
	# Create metallic ring/torus texture
	var size := ConfigManager.get_base_gem_size()
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var outer_radius := (size / 2.0) - 4.0
	var inner_radius := outer_radius * 0.4  # Hole in the center
	var ring_width := outer_radius - inner_radius

	# Light direction for metallic shading (top-left)
	var light_dir := Vector2(-0.6, -0.8).normalized()

	for x in range(size):
		for y in range(size):
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)

			if dist <= outer_radius and dist >= inner_radius and dist > 0.001:
				# Inside the ring
				var ring_pos: float = (dist - inner_radius) / ring_width  # 0 at inner, 1 at outer

				# Calculate surface normal for 3D torus effect
				var to_center: Vector2 = (center - pos) / dist  # Normalized direction to center
				var ring_center_dist: float = (inner_radius + outer_radius) / 2.0
				var tube_center: Vector2 = center - to_center * ring_center_dist
				var tube_dist: float = pos.distance_to(tube_center)
				var safe_dist: float = maxf(tube_dist, 0.001)
				var tube_normal: Vector2 = (pos - tube_center) / safe_dist  # Safe normalize

				# Lighting calculation
				var light_intensity: float = maxf(0.0, tube_normal.dot(-light_dir))

				# Add specular highlight
				var view_dir: Vector2 = Vector2(0, -1)  # Looking from above
				var dot_val: float = tube_normal.dot(-light_dir)
				var reflect: Vector2 = 2.0 * dot_val * tube_normal - (-light_dir)
				var specular: float = pow(maxf(0.0, reflect.dot(view_dir)), 32.0) * 0.7

				# Ring profile (darker at edges for depth)
				var profile: float = 1.0 - pow(absf(ring_pos * 2.0 - 1.0), 2.0) * 0.3

				# Combine lighting
				var brightness: float = 0.3 + light_intensity * 0.5 * profile + specular
				brightness = clampf(brightness, 0.15, 1.0)

				# Anti-aliasing at edges
				var aa_outer: float = _smooth_step(outer_radius, outer_radius - 1.5, dist)
				var aa_inner: float = _smooth_step(inner_radius, inner_radius + 1.5, dist)
				var alpha: float = aa_outer * aa_inner

				image.set_pixel(x, y, Color(brightness, brightness, brightness, alpha))
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)

	var texture := ImageTexture.create_from_image(image)
	return texture

func _smooth_step(edge0: float, edge1: float, x: float) -> float:
	var t: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _create_special_indicator() -> ImageTexture:
	var size := ConfigManager.get_base_gem_size()
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	var center := size / 2
	var margin := int(size * 0.15)  # 15% margin from edges
	var line_thickness := maxi(3, int(size * 0.06))  # At least 3 pixels thick

	match special_type:
		Enums.SpecialType.STRIPED_H:
			# Draw 3 horizontal lines across the gem
			var line_positions_h: Array[int] = [int(size * 0.3), center, int(size * 0.7)]
			for line_y in line_positions_h:
				for x in range(margin, size - margin):
					for t in range(line_thickness):
						var y: int = line_y - line_thickness / 2 + t
						if y >= 0 and y < size:
							image.set_pixel(x, y, Color.WHITE)

		Enums.SpecialType.STRIPED_V:
			# Draw 3 vertical lines across the gem
			var line_positions_v: Array[int] = [int(size * 0.3), center, int(size * 0.7)]
			for line_x in line_positions_v:
				for y in range(margin, size - margin):
					for t in range(line_thickness):
						var x: int = line_x - line_thickness / 2 + t
						if x >= 0 and x < size:
							image.set_pixel(x, y, Color.WHITE)

		Enums.SpecialType.WRAPPED:
			# Draw wrapper pattern (thicker corner brackets)
			var corner_len := int(size * 0.2)
			var edge := margin
			var far_edge := size - margin - 1
			for t in range(line_thickness):
				for i in range(corner_len):
					# Top-left corner
					image.set_pixel(edge + i, edge + t, Color.WHITE)
					image.set_pixel(edge + t, edge + i, Color.WHITE)
					# Top-right corner
					image.set_pixel(far_edge - i, edge + t, Color.WHITE)
					image.set_pixel(far_edge - t, edge + i, Color.WHITE)
					# Bottom-left corner
					image.set_pixel(edge + i, far_edge - t, Color.WHITE)
					image.set_pixel(edge + t, far_edge - i, Color.WHITE)
					# Bottom-right corner
					image.set_pixel(far_edge - i, far_edge - t, Color.WHITE)
					image.set_pixel(far_edge - t, far_edge - i, Color.WHITE)

		Enums.SpecialType.COLOR_BOMB:
			# Draw rainbow-ish pattern (star shape)
			var star_center := Vector2(center, center)
			for angle in range(0, 360, 30):
				var rad := deg_to_rad(angle)
				for dist in range(int(size * 0.12), int(size * 0.42)):
					var px := int(star_center.x + cos(rad) * dist)
					var py := int(star_center.y + sin(rad) * dist)
					if px >= 0 and px < size and py >= 0 and py < size:
						var hue := fmod(angle / 360.0 + dist / float(size * 0.42), 1.0)
						image.set_pixel(px, py, Color.from_hsv(hue, 1.0, 1.0))

	return ImageTexture.create_from_image(image)

func _animate_selection_ring() -> void:
	if not selection_ring:
		return
	var pulse_dur := ConfigManager.get_selection_pulse_duration()
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(selection_ring, "scale", Vector2(1.2, 1.2) * _sprite_scale, pulse_dur)
	tween.tween_property(selection_ring, "scale", Vector2(1.0, 1.0) * _sprite_scale, pulse_dur)

func _get_swipe_direction(swipe_vector: Vector2) -> Vector2:
	return Vector2(sign(swipe_vector.x), 0) if abs(swipe_vector.x) > abs(swipe_vector.y) else Vector2(0, sign(swipe_vector.y))

func _get_click_rect() -> Rect2:
	var half_size := ConfigManager.get_base_gem_size() * _tile_scale / 2.0
	return Rect2(-half_size, -half_size, half_size * 2, half_size * 2)

func _handle_click() -> void:
	if not is_falling and not GameManager.processing_moves:
		clicked.emit(self)

func _on_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int) -> void:
	pass

func _on_mouse_entered() -> void:
	if is_falling or GameManager.processing_moves or not sprite:
		return
	create_tween().tween_property(sprite, "scale", Vector2(_sprite_scale * 1.1, _sprite_scale * 1.1), ConfigManager.get_hover_scale_duration())

func _on_mouse_exited() -> void:
	if is_falling or not sprite:
		return
	create_tween().tween_property(sprite, "scale", Vector2(_sprite_scale, _sprite_scale), ConfigManager.get_hover_scale_duration())
