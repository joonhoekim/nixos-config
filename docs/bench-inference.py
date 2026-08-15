#!/usr/bin/env python3
"""LM Studio 로컬 API로 추론 속도를 재고 마크다운 표로 뱉는다.

docs/local-inference.md 의 성능 표가 이 스크립트로 나온 것이다. 같은 모델을
`--gpu max` 와 `--gpu off` 로 두 번 재서 iGPU 기여분을 분리한다.

    lms server start          # 먼저 서버가 떠 있어야 한다
    python3 docs/bench-inference.py
    python3 docs/bench-inference.py --models qwen3.8-27b --gpu max --reps 3

측정하는 것:
  생성 (tok/s)   짧은 프롬프트로 max_tokens 만큼 생성. reps 회 중 중앙값.
  TTFT (s)       첫 토큰까지. 두 번째 요청부터가 의미 있다(첫 회는 워밍업).
  프리필 (tok/s) 긴 프롬프트의 prompt_tokens / TTFT.
  CPU (코어)     생성 중 llama-server 가 실제로 쓴 코어 수. /proc 에서 직접 읽는다.

마지막 항목이 이 스크립트의 핵심이다. GPU/CPU 배수만 보면 "iGPU 가 CPU 보다 N 배
빠르다"로 읽게 되는데, LM Studio 는 llama-server 를 `--threads 6`(16 코어 중)으로
띄우고 실측 사용률은 그보다도 낮다. 그 사실이 결과표에 같이 찍혀야 배수를
"하드웨어 대 하드웨어"로 오독하지 않는다.

`lms load` 에는 스레드 수 옵션이 없다(0.4.21 기준). CPU 쪽을 제대로 재려면
GUI 의 모델 로드 설정에서 바꿔야 하고, 이 스크립트는 거기까진 못 한다.
"""
import argparse, json, subprocess, sys, time, urllib.error, urllib.request

FILLER = ("The quick brown fox jumps over the lazy dog near the riverbank while "
          "seventeen curious sparrows observe the scene from a nearby oak tree. ")
GEN_PROMPT = "Explain what a solid state drive is, in one paragraph."
CLK_TCK = 100  # getconf CLK_TCK; 리눅스 x86-64 에서 사실상 고정


def sh(args, timeout=1800):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        return 1, str(e)


def api(path, base, body=None, timeout=1800):
    url = f"{base}{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"} if data else {})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def med(xs):
    """진짜 중앙값. sorted(xs)[len//2] 는 짝수 개에서 큰 쪽으로 치우친다."""
    if not xs:
        return None
    s = sorted(xs)
    n = len(s)
    return s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2


def llama_pid():
    rc, out = sh(["pgrep", "-x", "llama-server"], timeout=10)
    return int(out.split()[0]) if rc == 0 and out.split() else None


def cpu_ticks(pid):
    """utime+stime (clock ticks). 프로세스가 사라졌으면 None."""
    try:
        with open(f"/proc/{pid}/stat") as f:
            parts = f.read().rsplit(")", 1)[1].split()
        return int(parts[11]) + int(parts[12])   # utime, stime (0-indexed after state)
    except (OSError, IndexError, ValueError):
        return None


def ask(base, prompt, max_tokens, pid=None):
    """요청을 보내고 stats + 그동안의 CPU 코어 사용량을 돌려준다."""
    t0, c0 = time.time(), (cpu_ticks(pid) if pid else None)
    d = api("/api/v0/chat/completions", base, {
        "model": "bench", "messages": [{"role": "user", "content": prompt}],
        "temperature": 0, "max_tokens": max_tokens, "stream": False})
    wall = time.time() - t0
    c1 = cpu_ticks(pid) if pid else None
    cores = ((c1 - c0) / CLK_TCK / wall) if (c0 is not None and c1 is not None and wall) else None
    return d.get("stats", {}), d.get("usage", {}), wall, cores


def bench(model, gpu, args):
    print(f"\n{'=' * 70}\n{model}  |  --gpu {gpu}\n{'=' * 70}", flush=True)
    sh(["lms", "unload", "--all"])
    t0 = time.time()
    rc, out = sh(["lms", "load", model, "--gpu", gpu,
                  "--context-length", str(args.context), "--identifier", "bench", "-y"])
    load_s = time.time() - t0
    if rc != 0:
        print(f"  로드 실패 (rc={rc}): {out.strip()[-300:]}")
        return None
    pid = llama_pid()
    print(f"  로드: {load_s:.1f}s   llama-server pid={pid}", flush=True)

    gens, ttfts, cores = [], [], []
    for i in range(args.reps):
        try:
            s, u, wall, c = ask(args.base, GEN_PROMPT, args.tokens, pid)
        except (urllib.error.URLError, OSError) as e:
            print(f"  gen {i + 1} 실패: {e}")
            break
        gens.append(s.get("tokens_per_second", 0))
        ttfts.append(s.get("time_to_first_token", 0))
        if c is not None:
            cores.append(c)
        print(f"  gen {i + 1}: {gens[-1]:6.2f} tok/s  TTFT {ttfts[-1]:5.2f}s  "
              f"out {u.get('completion_tokens', 0)} tok  wall {wall:5.1f}s"
              + (f"  CPU {c:.1f}코어" if c is not None else ""), flush=True)

    prefill = None
    if not args.no_prefill:
        try:
            s, u, _, _ = ask(args.base, FILLER * args.filler_reps
                             + "\n\nSummarize the above in one sentence.", 16, pid)
            pt, ttft = u.get("prompt_tokens", 0), s.get("time_to_first_token", 0)
            if ttft:
                prefill = pt / ttft
                print(f"  prefill: {pt} tok / {ttft:.2f}s = {prefill:.1f} tok/s", flush=True)
        except (urllib.error.URLError, OSError) as e:
            # --gpu max + 긴 프롬프트에서 HTTP 400 이 관측된 적이 있다.
            # local-inference.md 의 미해결 항목 참고.
            print(f"  prefill 실패: {e}")

    sh(["lms", "unload", "--all"])
    # TTFT 는 첫 회를 버린다. 모델을 갓 올린 직후의 1 회차는 캐시가 비어 있어
    # 정상 상태의 몇 배가 나오고(관측: 13.8s 대 2.1s), 그 값이 표에 실리면
    # "GPU 를 껐더니 첫 토큰이 13 초" 라는 잘못된 인상을 준다.
    steady = ttfts[1:] if len(ttfts) > 1 else ttfts
    return {"model": model, "gpu": gpu, "load_s": round(load_s, 1),
            "gen_tok_s": round(med(gens), 2) if gens else None,
            "ttft_s": round(med(steady), 2) if steady else None,
            "prefill_tok_s": round(prefill, 1) if prefill else None,
            "cpu_cores": round(med(cores), 1) if cores else None}


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--models", nargs="+", help="모델 키. 생략하면 API 가 아는 LLM 전부")
    p.add_argument("--gpu", nargs="+", default=["max", "off"],
                   help='오프로드 설정. "max", "off", 또는 0~1 (기본: max off)')
    p.add_argument("--reps", type=int, default=3, help="생성 측정 반복 (기본 3)")
    p.add_argument("--tokens", type=int, default=200, help="생성 토큰 수 (기본 200)")
    p.add_argument("--context", type=int, default=4096, help="컨텍스트 길이 (기본 4096)")
    p.add_argument("--filler-reps", type=int, default=60,
                   help="프리필 프롬프트 반복 횟수. 60 이면 약 1650 토큰")
    p.add_argument("--no-prefill", action="store_true", help="프리필 측정 생략")
    p.add_argument("--port", type=int, default=1234)
    p.add_argument("--json", help="결과를 JSON 으로 저장할 경로")
    args = p.parse_args()
    args.base = f"http://127.0.0.1:{args.port}"

    if sh(["lms", "version"], timeout=30)[0] != 0:
        sys.exit("lms 를 찾을 수 없다. ~/.local/bin/lms 링크를 확인할 것 "
                 "(docs/local-inference.md 4절).")
    try:
        models = api("/api/v0/models", args.base)
    except (urllib.error.URLError, OSError) as e:
        sys.exit(f"서버에 못 붙었다 ({e}). 먼저 `lms server start`.")

    if args.models:
        targets = args.models
    else:
        targets = [m["id"] for m in models.get("data", [])
                   if m.get("type") in ("llm", "vlm")]
    if not targets:
        sys.exit("잴 모델이 없다. `lms ls` 로 확인할 것.")
    print(f"대상 모델: {', '.join(targets)}\n오프로드: {', '.join(args.gpu)}")

    rows = [r for r in (bench(m, g, args) for m in targets for g in args.gpu) if r]

    print("\n\n" + "=" * 70 + "\n결과 (마크다운)\n" + "=" * 70)
    print("| 모델 | GPU | 로드 | 생성 (tok/s) | TTFT | 프리필 (tok/s) | CPU (코어) |")
    print("|---|---|---|---|---|---|---|")
    f = lambda v, suf="": f"{v}{suf}" if v is not None else "—"
    for r in rows:
        print(f"| {r['model']} | {r['gpu']} | {f(r['load_s'], ' s')} | "
              f"{f(r['gen_tok_s'])} | {f(r['ttft_s'], ' s')} | "
              f"{f(r['prefill_tok_s'])} | {f(r['cpu_cores'])} |")

    if args.json:
        with open(args.json, "w") as fh:
            json.dump(rows, fh, indent=2)
        print(f"\nJSON: {args.json}")


if __name__ == "__main__":
    main()
