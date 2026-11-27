"""Differential fuzzing: random typing through the legacy C++ engine and the real C++/Rust bridge.

The fixture corpus only covers hand-picked words. This compares the visible text after every key
for random mixed-case input across every input method, code table, accent style and option
profile. CI uses a fixed seed so runs are reproducible; pass --seed to explore new inputs.

    python3 scripts/fuzz-rust-engine.py --cases 100000 --seed 1
"""
from pathlib import Path
import argparse
import random
import tempfile

import enginebuild

KNOWN = Path(__file__).with_name("fuzz-known-divergences.txt")
VNI_WORDS = "tie6ng vie65t ngu7o72i qua1 to6i la2 nam duo7c d9u7o7ng ho1a khuye6n3 gio6ng1".split()
TELEX_WORDS = "tieengs vieetj nguwowif quas tooi laf ddwowcj dduwowngf hoas thuowr khuyeenx gioongs quaanf".split()
LETTERS = "aeiouydwsfrxjzqgnhtcmpbklv"
PROFILES = [0, 0, 0, 1, 2, 4, 8, 16, 24, 32, 64, 2 | 4, 2 | 64, 2 | 32, 1 | 2]


def case(rng: random.Random) -> str:
    mode, code, modern = rng.randrange(4), rng.randrange(5), rng.randrange(2)
    profile = rng.choice(PROFILES)
    marks = "123456789" if mode == 1 else "sfrxjwz"
    if rng.random() < 0.5:
        text = list(" ".join(rng.choice(VNI_WORDS if mode == 1 else TELEX_WORDS) for _ in range(rng.randint(1, 3))))
        for _ in range(rng.randint(0, 3)):
            text.insert(rng.randrange(len(text) + 1), rng.choice("<[]" + marks))
        text = "".join(text)
    else:
        keys = LETTERS + ("1234567890" * 2 if mode == 1 else "") + "[]<  ,."
        text = "".join(rng.choice(keys) for _ in range(rng.randint(1, 14)))
    roll = rng.random()
    if roll < 0.25:
        text = text.upper()
    elif roll < 0.45:
        text = "".join(c.upper() if rng.random() < 0.3 else c for c in text)
    return f"{mode} {code} {modern} {profile}\t{text.strip() or 'a'}"


def visible(trace: str) -> list[str]:
    return ["".join(chr(int(c) & 0xFFFF) for c in step.split(",") if c) for step in trace.split(";") if step]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--cases", type=int, default=100_000)
    parser.add_argument("--seed", type=int, default=1)
    args = parser.parse_args()
    rng = random.Random(args.seed)
    cases = [case(rng) for _ in range(args.cases)]
    known = {line for line in KNOWN.read_text().splitlines() if line and not line.startswith("#")}
    with tempfile.TemporaryDirectory(prefix="openkey-fuzz-") as tmp:
        expected = enginebuild.run(enginebuild.reference(Path(tmp) / "reference"), cases)
        actual = enginebuild.run(enginebuild.bridge(Path(tmp) / "bridge", Path(tmp) / "rust"), cases)
    failures = [(c, e, a) for c, e, a in zip(cases, expected, actual) if e != a and c not in known]
    for c, e, a in failures[:10]:
        print(f"Mismatch: {c!r}\n  C++:  {visible(e.split(chr(9))[2])}\n  Rust: {visible(a.split(chr(9))[2])}")
    if len(expected) != len(cases) or len(actual) != len(cases):
        raise SystemExit("Engine output was truncated")
    if failures:
        raise SystemExit(f"{len(failures)} of {len(cases)} random traces differ (seed {args.seed})")
    print(f"Differential fuzz: {len(cases)} random traces matched (seed {args.seed}, {len(known)} known divergences)")


if __name__ == "__main__":
    main()
