// glow.glsl — 인광체 잔광만. crt.glsl 에서 매일 쓸 만한 부분만 남긴 것이다.
//
// 곡률도 색수차도 그릴도 없다. 글자가 살짝 번지고 스캔라인이 아주 얕게 깔릴
// 뿐이라 본문 가독성은 그대로다. iTime 을 안 쓰므로 glow.conf 에서
// custom-shader-animation 을 꺼 두었다 — 화면이 바뀔 때만 그린다.

#define BLOOM       0.70
#define BLOOM_CUT   0.35
#define SCAN_PX     3.0
#define SCAN_DEPTH  0.08
#define BRIGHTNESS  1.06

vec3 bloom(vec2 uv, vec2 px) {
    vec3 sum = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.78539816;   // 2π/8
        vec2 dir = vec2(cos(a), sin(a));
        for (int j = 1; j <= 2; j++) {
            vec3 c = texture(iChannel0, uv + dir * px * float(j) * 3.0).rgb;
            sum += max(c - BLOOM_CUT, 0.0) / float(j);
        }
    }
    return sum / 12.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 px = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * px;

    vec4 src = texture(iChannel0, uv);
    vec3 col = src.rgb + bloom(uv, px) * BLOOM;

    col *= 1.0 - SCAN_DEPTH * (0.5 + 0.5 * sin(fragCoord.y * 6.2831853 / SCAN_PX));
    col *= BRIGHTNESS;

    // crt 와 달리 알파를 살려 둔다. 여기는 창을 도려내지 않으므로 배경 투명도가
    // 그대로 통해야 한다.
    fragColor = vec4(col, src.a);
}
