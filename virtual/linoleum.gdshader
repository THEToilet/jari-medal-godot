shader_type spatial;
// ショッピングモールのリノリウム床：クリーム系の市松＋細かい石目＋目地
uniform vec3 tile_a : source_color = vec3(0.88, 0.86, 0.80);
uniform vec3 tile_b : source_color = vec3(0.80, 0.81, 0.79);
uniform vec3 grout : source_color = vec3(0.62, 0.62, 0.60);
uniform float tile_size = 0.3;
uniform float speckle = 0.06;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 p = world_pos.xz / tile_size;
	vec2 cell = floor(p);
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 col = mix(tile_a, tile_b, checker);
	// タイルごとのわずかな色むら
	col *= 0.97 + 0.06 * hash(cell);
	// 石目（細かい斑点＋ゆるいまだら）
	float n = noise(p * 9.0) * 0.6 + noise(p * 31.0) * 0.4;
	float dots = step(0.93, hash(floor(p * 70.0)));
	col *= 1.0 - speckle * (n - 0.5) * 2.0;
	col = mix(col, col * 0.75, dots * 0.6);
	// 目地
	vec2 f = abs(fract(p) - 0.5);
	float line = smoothstep(0.492, 0.497, max(f.x, f.y));
	col = mix(col, grout, line * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.32 + 0.1 * n;
	SPECULAR = 0.6;
}
