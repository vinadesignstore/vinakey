"""Shared build steps for the engine scripts: legacy C++ reference and the real C++/Rust bridge."""
from pathlib import Path
import platform
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
CARGO = shutil.which("cargo") or str(Path.home() / ".cargo/bin/cargo")
LEGACY = [f"Sources/OpenKey/engine/{x}.cpp" for x in ["Macro", "SmartSwitchKey", "Vietnamese", "ConvertTool"]]
# libc++ on macOS pulls these in transitively; libstdc++ on Linux does not.
CXX = ["clang++", "-std=c++17", "-Wno-deprecated-declarations", "-include", "cstdint", "-include", "algorithm"]
if platform.system() == "Darwin":
    LINK = ["-framework", "Security", "-framework", "CoreFoundation", "-liconv"]
else:
    LINK = ["-lpthread", "-ldl", "-lm"]


def reference(output: Path) -> str:
    """The unchanged legacy C++ engine driven by scripts/engine-fixtures.cpp."""
    subprocess.run([*CXX, "-DOPENKEY_REFERENCE", "scripts/engine-fixtures.cpp", *LEGACY, "-o", str(output)], cwd=ROOT, check=True)
    return str(output)


def bridge(output: Path, target_dir: Path) -> str:
    """The same driver linked against RustBridge.cpp and the release Rust static library."""
    subprocess.run([CARGO, "build", "--locked", "--release", "--manifest-path", "Sources/OpenKey/engine-rust/Cargo.toml", "--target-dir", str(target_dir)], cwd=ROOT, check=True)
    library = target_dir / "release/libopenkey_engine.a"
    subprocess.run([*CXX, "-DOPENKEY_FIXTURE_TEST", "scripts/engine-fixtures.cpp", "Sources/OpenKey/engine-rust/RustBridge.cpp", str(library), *LINK, "-o", str(output)], cwd=ROOT, check=True)
    return str(output)


def run(binary: str, cases: list[str]) -> list[str]:
    """Each case is `mode code modern profile<TAB>keys`; returns one trace line per case."""
    result = subprocess.run([binary], input="\n".join(cases) + "\n", text=True, capture_output=True, check=True)
    return result.stdout.splitlines()
