# avro-cpp 1.12.0 헤더를 fmt 12 에서 쓸 수 있게 고친다. kcat 때문에 둔다.
#
# avro/Exception.hh 는 <fmt/core.h> 만 include 하고 fmt::format 을 부른다.
# fmt 11 까지는 core.h 가 format 을 끌어왔지만, fmt 12 에서 core.h 는 base.h 만
# 싣는다. avro-cpp 자체는 빌드되지만, 이 헤더를 쓰는 쪽이 깨진다 —
# modules/shared/packages.nix 의 kcat -> libserdes 가 "no member named 'format'
# in namespace 'fmt'" 로 멈춘다(darwin 에서 확인, linux 도 캐시에 libserdes 가 없다).
#
# include 를 <fmt/format.h> 로 바꾸면 된다. 이 오버레이로 kcat 을 빌드해
# `kcat -V` 가 Avro 지원을 포함해 뜨는 것까지 확인했다.
#
# 지우는 조건: nixpkgs 의 avro-cpp 가 이 include 를 고치거나 1.12.1 이상으로
# 올라가서 헤더가 바뀌면 --replace-fail 이 빌드를 멈춘다. 그때 이 파일을 지우고
# kcat 이 빌드되는지 본다.
final: prev: {
  avro-cpp = prev.avro-cpp.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace include/avro/Exception.hh \
        --replace-fail '#include <fmt/core.h>' '#include <fmt/format.h>'
    '';
  });
}
