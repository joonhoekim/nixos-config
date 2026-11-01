// glow.glsl — crt.glsl 에서 블룸과 얕은 스캔라인만 남긴 상시용. 블룸은 crt.glsl 과 같은 나선 + 소프트 니여야 한다
// (링은 별 모양 결, 하드 임계값은 번짐이 튄다). 코드를 공유할 방법이 없으니 crt.glsl 을 원본으로 본다.

#define TAU 6.2831853

#define BLOOM       0.69              // @0..1.5
#define BLOOM_PX    8.2               // @1..16
#define BLOOM_CUT   0.30              // @0..1
#define BLOOM_KNEE  0.28              // @0.01..0.6

// 3 픽셀이면 한 주기에 표본이 세 개뿐이라 모아레가 된다. crt.glsl 과 같은 4.
#define SCAN_PX     4.0               // @2..8
#define SCAN_DEPTH  0.08              // @0..0.5

#define BRIGHTNESS  1.06              // @0.6..1.8

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

    // 창을 도려내지 않으므로 알파를 그대로 살려야 배경 투명도가 통한다.
    fragColor = vec4(col, src.a);
}
