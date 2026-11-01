# avro-cpp 1.12.0 의 avro/Exception.hh 는 <fmt/core.h> 만 넣고 fmt::format 을 부르는데, fmt 12 의 core.h 는 base.h 만 싣는다.
# 그래서 이 헤더를 쓰는 kcat -> libserdes 가 "no member named 'format' in namespace 'fmt'" 로 멈춘다(darwin 에서 확인).
# 지우는 조건: 헤더가 바뀌면 --replace-fail 이 빌드를 멈춘다 — 그때 이 파일을 지우고 kcat 이 빌드되는지 본다.
final: prev: {
  avro-cpp = prev.avro-cpp.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace include/avro/Exception.hh \
        --replace-fail '#include <fmt/core.h>' '#include <fmt/format.h>'
    '';
  });
}
