#!/usr/bin/env python3
"""Build a universal local preview or a signed, notarized VinaKey archive."""
import argparse
import hashlib
import json
import plistlib
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--release", action="store_true")
    parser.add_argument("--identity", help="Installed Developer ID Application identity")
    parser.add_argument("--notary-profile", help="Existing notarytool Keychain profile; never a password")
    args = parser.parse_args()
    if args.release and (not args.identity or not args.identity.startswith("Developer ID Application:") or not args.notary_profile):
        parser.error("--release requires a Developer ID Application --identity and --notary-profile")
    if not args.release and (args.identity or args.notary_profile):
        parser.error("Signing credentials are only accepted with --release")
    if args.release:
        identities = run("security", "find-identity", "-v", "-p", "codesigning", capture_output=True).stdout
        if f'"{args.identity}"' not in identities:
            parser.error("The requested Developer ID Application identity is not installed")
    output = args.output.expanduser().resolve()
    # Never replace an installed/running app or an earlier review artifact.
    if output.exists() and any(output.iterdir()):
        parser.error("Output directory must be empty")
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="vinakey-package-") as temporary:
        stage = Path(temporary)
        with (output / "build.log").open("w") as log:
            run("xcodebuild", "-project", str(ROOT / "Sources/OpenKey/macOS/OpenKey.xcodeproj"),
                "-scheme", "OpenKey", "-configuration", "Release", "-derivedDataPath", str(stage / "build"),
                "CODE_SIGNING_ALLOWED=NO", "MACOSX_DEPLOYMENT_TARGET=12.0", "build", cwd=ROOT,
                stdout=log, stderr=subprocess.STDOUT)
        app = stage / "VinaKey.app"
        run("ditto", str(stage / "build/Build/Products/Release/VinaKey.app"), str(app))
        with (app / "Contents/Info.plist").open("rb") as handle:
            info = plistlib.load(handle)
        if info["CFBundleIdentifier"] != "com.vinadesignstore.vinakey" or info["CFBundleExecutable"] != "VinaKey":
            raise RuntimeError("Unexpected app identity")
        architectures = run("lipo", "-archs", str(app / "Contents/MacOS/VinaKey"), capture_output=True).stdout.split()
        if set(architectures) != {"arm64", "x86_64"}:
            raise RuntimeError(f"Expected universal app, got {architectures}")
        identity = args.identity if args.release else "-"
        signing = ["codesign", "--force", "--sign", identity, "--options", "runtime",
                   "--timestamp" if args.release else "--timestamp=none"]
        # Sign embedded code before the enclosing app; do not use --deep for signing.
        macho = {b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"}
        frameworks = app / "Contents/Frameworks"
        if frameworks.exists():
            for item in sorted(frameworks.rglob("*"), key=lambda path: len(path.parts), reverse=True):
                if item.is_file() and not item.is_symlink():
                    with item.open("rb") as handle:
                        if handle.read(4) in macho:
                            run(*signing, str(item))
        run(*signing, str(app))
        run("codesign", "--verify", "--deep", "--strict", str(app))
        if args.release:
            upload = stage / "notarization.zip"
            run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(upload))
            result = run("xcrun", "notarytool", "submit", str(upload), "--keychain-profile", args.notary_profile,
                         "--wait", "--output-format", "json", capture_output=True)
            submission = json.loads(result.stdout)
            (output / "notarization.json").write_text(json.dumps(submission, indent=2) + "\n")
            if submission.get("status") != "Accepted":
                if submission.get("id"):
                    run("xcrun", "notarytool", "log", submission["id"], "--keychain-profile", args.notary_profile,
                        str(output / "notarization-log.json"))
                raise RuntimeError("Notarization was not accepted; no release archive produced")
            run("xcrun", "stapler", "staple", str(app))
            run("xcrun", "stapler", "validate", str(app))
            run("spctl", "--assess", "--type", "execute", "--verbose=2", str(app))
        version = info["CFBundleShortVersionString"]
        archive = output / f"VinaKey-{version}{'' if args.release else '-local-preview'}.zip"
        run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(archive))
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        (output / "SHA256SUMS").write_text(f"{digest}  {archive.name}\n")
        (output / "manifest.json").write_text(json.dumps({
            "version": version, "build": info["CFBundleVersion"], "architectures": architectures,
            "bundle_id": info["CFBundleIdentifier"], "notarized": args.release,
            "signing": "Developer ID Application" if args.release else "ad-hoc local preview",
            "commit": run("git", "rev-parse", "HEAD", cwd=ROOT, capture_output=True).stdout.strip(),
            "sha256": digest,
        }, indent=2) + "\n")
        print(archive)


if __name__ == "__main__":
    main()
