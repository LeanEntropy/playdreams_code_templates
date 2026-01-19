shader_type canvas_item;

uniform vec4 color_light : source_color = vec4(0.96, 0.92, 0.84, 1.0);
uniform vec4 color_dark : source_color = vec4(0.91, 0.87, 0.78, 1.0);
uniform float tile_size : hint_range(10.0, 200.0) = 60.0;

void fragment() {
	vec2 pos = FRAGCOORD.xy / tile_size;
	float checker = mod(floor(pos.x) + floor(pos.y), 2.0);
	COLOR = mix(color_light, color_dark, checker);
}
