# VinaKey Rust engine

The macOS app now links this dependency-free Rust static library instead of the five legacy C++ engine sources. AppKit owns the menu bar, settings window and keyboard event tap; SwiftUI renders grouped settings forms on macOS 13 and later. `RustBridge.cpp` adapts the existing Objective-C++ callers; composition, spelling, macros, encoding conversion and remembered app data run in Rust. Windows and Linux source/build files are unchanged.

## Build and verify

Install Rust through rustup. The repository pins Rust 1.100.0 and both macOS architecture targets in `rust-toolchain.toml`.

From the repository root:

```sh
cargo test --locked --manifest-path Sources/OpenKey/engine-rust/Cargo.toml
cargo clippy --locked --manifest-path Sources/OpenKey/engine-rust/Cargo.toml --all-targets -- -D warnings
python3 scripts/check-rust-engine.py
python3 scripts/fuzz-rust-engine.py --cases 100000 --seed 1
xcodebuild -project Sources/OpenKey/macOS/OpenKey.xcodeproj -scheme OpenKey \
  -configuration Release -derivedDataPath /tmp/openkey-rust-build \
  CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=12.0 build
```

Xcode builds each requested architecture with Cargo, combines the libraries with `lipo`, and links Rust statically. There is no Rust runtime to install on users’ Macs. The deployment target is macOS 12; older systems are not supported.

## Behavior and checks

- 8,073 independent legacy C++ traces compare the visible text after **every** key: four input modes, five encodings, both accent-placement modes, backspace, boundaries, restoration, quick typing, capitalization and macros.
- The same corpus exercises the real C++/Rust bridge. `scripts/capture-engine-fixtures.py` regenerates fixtures from the unchanged C++ engine.
- `scripts/fuzz-rust-engine.py` types random mixed-case input through both the legacy C++ engine and the real bridge and compares the text after every key. CI runs 100,000 cases with seed 1; pass other seeds to explore. `scripts/fuzz-known-divergences.txt` lists inputs where the C++ engine itself misbehaves.
- The engine scripts, the bridge and the C++ reference build on Linux as well as macOS; CI runs them on Ubuntu.
- Native Rust tests also cover 500,000 deterministic random editing events, C ABI layout and invalid inputs, transactional parsing of truncated macro/app data, UTF-16 macro content and encoding round-trips.
- Legacy macro/app binary formats are retained. Oversized entries and malformed UTF-8 are rejected before replacing loaded data.
- Conversion intentionally preserves case unless a case option is selected, keeps supplementary Unicode characters intact, and omits the legacy converter’s trailing NUL. These are covered explicitly instead of copying its lowercasing bug.
- Quick consonant expansion is skipped when its output would exceed the 32-character native result buffer. Editing history retains the most recent 256 chunks.

The C ABI (`OpenKeyRust.h`) names its command and option values; a test checks them, and the C++ hook codes in `DataType.h`, against Rust. It owns opaque engine handles and explicitly freed byte buffers. Each handle must be used serially; the existing macOS event loop satisfies this. No Rust references, STL containers or allocator-owned strings cross the ABI. Panics in processing/commands are caught before returning to native callers.

## Regenerate tables

```sh
clang++ -std=c++17 scripts/export-rust-tables.cpp Sources/OpenKey/engine/Vietnamese.cpp -o /tmp/openkey-tables
/tmp/openkey-tables > Sources/OpenKey/engine-rust/src/tables.rs
cargo fmt --manifest-path Sources/OpenKey/engine-rust/Cargo.toml
```

The data and algorithms derive from OpenKey and retain GPL-3.0 licensing and attribution.

Milestone checkpoints and live test results are in [VALIDATION.md](VALIDATION.md).
