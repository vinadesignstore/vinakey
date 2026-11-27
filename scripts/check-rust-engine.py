"""Build and exercise the actual C++/Rust ABI against captured legacy typing traces."""
from pathlib import Path
import tempfile

import enginebuild

fixtures = (enginebuild.ROOT / "Sources/OpenKey/engine-rust/tests/reference.tsv").read_text().splitlines()
inputs = ["\t".join(line.split("\t")[:2]) for line in fixtures]
with tempfile.TemporaryDirectory(prefix="openkey-abi-") as tmp:
    binary = enginebuild.bridge(Path(tmp) / "bridge-test", Path(tmp) / "rust")
    output = enginebuild.run(binary, inputs)
    if len(output) != len(fixtures):
        raise SystemExit(f"Expected {len(fixtures)} traces, received {len(output)}")
    failures = [i for i, (expected, actual) in enumerate(zip(fixtures, output)) if expected != actual]
    if failures:
        for i in failures[:10]:
            print(f"Mismatch at fixture {i+1}: {inputs[i]}")
        raise SystemExit(f"{len(failures)} native bridge mismatches")
print(f"Native C++/Rust bridge: {len(fixtures)} reference traces matched")
