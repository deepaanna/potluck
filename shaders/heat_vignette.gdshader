shader_type canvas_item;

uniform float heat_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.9, 0.15, 0.05, 1.0);
uniform float radius : hint_range(0.0, 1.5) = 0.8;
uniform float softness : hint_range(0.01, 1.0) = 0.4;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 2.0;
	float vignette = smoothstep(radius, radius + softness, dist);
	float alpha = vignette * heat_intensity * 0.7;
	COLOR = vec4(vignette_color.rgb, alpha);
}
