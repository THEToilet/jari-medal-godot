shader_type spatial;
render_mode unshaded, cull_back;
// 一昔前のブラウン管モニター風。筐体の Screen に貼る（virtual_cabinet.gd が screen_tex にゲーム画面を入れる）

uniform sampler2D screen_tex : source_color, filter_linear, repeat_disable;
uniform float curvature : hint_range(0.0, 0.3) = 0.09;          // 画面のふくらみ
uniform float corner : hint_range(0.0, 0.2) = 0.06;             // 角の丸み
uniform float scanline_count = 240.0;                           // 走査線の本数（上限。画面が小さく映るときは自動で減らす）
uniform float scanline_min_px = 3.0;                            // 走査線1本あたりの最小の太さ（px）
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.2;
uniform float mask_strength : hint_range(0.0, 1.0) = 0.08;
uniform float aberration : hint_range(0.0, 0.01) = 0.0007;      // 色のにじみ（左右ずれ）
uniform float bleed : hint_range(0.0, 1.0) = 0.15;              // 明るいところのにじみ
uniform float vignette : hint_range(0.0, 1.0) = 0.25;           // 周辺の暗さ
uniform float brightness : hint_range(0.5, 2.0) = 1.08;         // 走査線で暗くなるぶんの持ち上げ
uniform float flicker : hint_range(0.0, 0.1) = 0.004;           // ちらつき
uniform float glass : hint_range(0.0, 0.3) = 0.05;              // ガラスの映り込み

vec2 warp(vec2 uv) {
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + curvature * vec2(c.y * c.y, c.x * c.x);
	c /= 1.0 + curvature;
	return c * 0.5 + 0.5;
}

// 細かすぎて潰れる模様は消す（遠くから見たときのモアレ防止）
float fade_by_density(float coord) {
	return clamp(1.6 - fwidth(coord) * 2.2, 0.0, 1.0);
}

void fragment() {
	vec2 uv = warp(UV);

	// 角を丸めた画面の外は黒
	vec2 q = abs(uv * 2.0 - 1.0);
	vec2 d = max(q - (1.0 - corner), 0.0);
	float inside = 1.0 - smoothstep(corner - 0.01, corner, length(d));
	inside *= step(q.x, 1.0) * step(q.y, 1.0);

	// 色ずれ
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(aberration, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(aberration, 0.0)).b;

	// にじみ（周りの明るさを少し足す）
	vec2 px = vec2(0.003, 0.004);
	vec3 halo = texture(screen_tex, uv + vec2(px.x, 0.0)).rgb + texture(screen_tex, uv - vec2(px.x, 0.0)).rgb
		+ texture(screen_tex, uv + vec2(0.0, px.y)).rgb + texture(screen_tex, uv - vec2(0.0, px.y)).rgb;
	col += halo * 0.25 * bleed * 0.5;

	// 走査線
	float px_per_screen = 1.0 / max(fwidth(UV.y), 1e-5);   // 画面の高さが今何pxで映っているか
	float lines = clamp(floor(px_per_screen / scanline_min_px / 16.0) * 16.0, 48.0, scanline_count);
	float sl = uv.y * lines;
	float line = 0.5 + 0.5 * cos(sl * 6.2831853);
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	float s = mix(1.0 - scanline_strength * (1.0 - lum * 0.5), 1.0, line);   // 明るい線ほど太る
	col *= mix(1.0, s, fade_by_density(sl));

	// RGBの縦じま（アパーチャーグリル）。表示のピクセルにそろえる
	float ph = mod(floor(FRAGCOORD.x), 3.0);
	vec3 mask = vec3(ph == 0.0 ? 1.0 : 1.0 - mask_strength, ph == 1.0 ? 1.0 : 1.0 - mask_strength, ph == 2.0 ? 1.0 : 1.0 - mask_strength);
	col *= mask;

	col *= brightness;

	// 周辺減光
	vec2 v = uv * (1.0 - uv);
	col *= pow(clamp(v.x * v.y * 16.0, 0.0, 1.0), vignette);

	// ちらつき
	col *= 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 47.0));

	// ガラスの映り込み（左上からのうっすらした光）
	float g = smoothstep(0.9, 0.0, length(UV - vec2(0.2, 0.15)));
	col += vec3(glass) * g * g;

	ALBEDO = mix(vec3(0.015), col, inside);
}
