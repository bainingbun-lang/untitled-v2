shader_type spatial;

// La mascara esta en espacio UV y se pinta con los impactos, asi la herida sigue a la malla.
uniform sampler2D damage_mask : filter_linear;
uniform vec4 wound_color : source_color = vec4(0.45, 0.02, 0.02, 1.0);
uniform float wound_strength = 1.0;

void fragment() {
	float m = texture(damage_mask, UV).r;
	ALBEDO = mix(ALBEDO, wound_color.rgb, clamp(m * wound_strength, 0.0, 1.0));
	ROUGHNESS = mix(0.8, 0.4, m);
}
