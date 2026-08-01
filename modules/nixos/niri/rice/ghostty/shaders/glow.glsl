// glow.glsl — 인광체 잔광만. crt.glsl 에서 매일 쓸 만한 부분만 남긴 것이다.
//
// 곡률도 색수차도 그릴도 없다. 글자가 살짝 번지고 스캔라인이 아주 얕게 깔릴
// 뿐이라 본문 가독성은 그대로다. iTime 을 안 쓰므로 glow.conf 에서
// custom-shader-animation 을 꺼 두었다 — 화면이 바뀔 때만 그린다.
//
// 남긴 부분은 crt.glsl 과 같은 방식이어야 한다. 처음에는 여기만 링 8방향 + 하드
// 임계값으로 따로 짜 뒀는데, 그건 crt.glsl 이 머리말에서 "이래서 안 쓴다"고 적어
// 둔 바로 그 방식이었다 — 링은 밝은 글자 둘레에 방향 수만큼 별 모양 결을 남기고,
// 하드 임계값은 글자 굵기에 따라 번짐이 튄다. 상시로 쓸 룩이 오히려 그 결함을
// 안고 있었던 셈이라, 나선 + 소프트 니로 맞췄다. 두 파일 사이에 코드를 공유할
// 방법은 없다(각각 독립된 프로그램이다). crt.glsl 이 원본이라고 생각하면 된다.

#define TAU 6.2831853

#define BLOOM       0.70
#define BLOOM_PX    6.0
#define BLOOM_CUT   0.30
#define BLOOM_KNEE  0.28

// 3 픽셀이면 한 주기에 표본이 세 개뿐이라 모아레가 된다. crt.glsl 과 같은 4.
#define SCAN_PX     4.0
#define SCAN_DEPTH  0.08

#define BRIGHTNESS  1.06

// 골든앵글 나선 16탭. 반경을 sqrt 로 잡아야 표본이 면적에 고르게 퍼진다.
vec3 bloom(vec2 uv, vec2 px) {
    vec3 sum = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < 16; i++) {
        float fi = float(i) + 0.5;
        float r  = sqrt(fi / 16.0);
        float a  = fi * 2.39996323;          // 황금각
        float w  = exp(-r * r * 1.8);        // 가우시안 가중
        vec3  c  = texture(iChannel0, uv + vec2(cos(a), sin(a)) * r * BLOOM_PX * px).rgb;
        float l  = dot(c, vec3(0.2126, 0.7152, 0.0722));
        sum  += c * smoothstep(BLOOM_CUT, BLOOM_CUT + BLOOM_KNEE, l) * w;
        wsum += w;
    }
    return sum / wsum;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 px = 1.0 / iResolution.xy;
    vec2 uv = fragCoord * px;

    vec4 src = texture(iChannel0, uv);
    vec3 col = src.rgb + bloom(uv, px) * BLOOM;

    col *= 1.0 - SCAN_DEPTH * (0.5 + 0.5 * sin(fragCoord.y * TAU / SCAN_PX));
    col *= BRIGHTNESS;

    // crt 와 달리 알파를 살려 둔다. 여기는 창을 도려내지 않으므로 배경 투명도가
    // 그대로 통해야 한다.
    fragColor = vec4(col, src.a);
}
