shader_type spatial;

render_mode unshaded, depth_draw_opaque;

uniform float alpha : source_color = 0.3;

void fragment() {
    ALBEDO = vec3(1.0, 0.0, 0.0);
    ALPHA = alpha;
}
