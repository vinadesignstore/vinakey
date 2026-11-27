# VinaKey macOS release procedure

The current candidate is **0.1.0 (1)**, universal arm64/x86_64, macOS 12+.
Native launch-at-login support requires macOS 13+ and uses `SMAppService.mainAppService`.
On macOS 12, add the application through the system Login Items settings instead.

## Verify the source

Start from a clean checkout of the commit being released:

```sh
cargo test --locked --manifest-path Sources/OpenKey/engine-rust/Cargo.toml
cargo clippy --locked --manifest-path Sources/OpenKey/engine-rust/Cargo.toml --all-targets -- -D warnings
python3 scripts/check-rust-engine.py
python3 scripts/fuzz-rust-engine.py --cases 100000 --seed 1
sh scripts/check-macos-input.sh
```

## Local review candidate

```sh
python3 scripts/package-macos.py --output /tmp/vinakey-local-candidate
```

The output directory must be empty. It contains a universal ZIP, SHA256SUMS,
manifest and build log. This is an **ad-hoc signed local preview**, not a notarized
public release. Packaging stages a copy and never replaces an installed app.

## Signed public candidate

Install a **Developer ID Application** certificate and its private key in the
local Keychain. Remove the inherited upstream development team from project
settings; VinaKey does not use the upstream author's signing identity.

Store notarization credentials locally using the interactive command below.
Do not put passwords, private keys or exported certificates in Git, logs or chat:

```sh
xcrun notarytool store-credentials vinakey-notary
```

Then run:

```sh
python3 scripts/package-macos.py --release \
  --identity 'Developer ID Application: YOUR NAME (TEAMID)' \
  --notary-profile vinakey-notary \
  --output /tmp/vinakey-public-candidate
```

The script builds both architectures, signs embedded code then the enclosing app
with hardened runtime and a secure timestamp, submits a ZIP with `notarytool`,
requires an **Accepted** result, staples and validates the ticket, and runs a
Gatekeeper assessment before producing the final archive and checksum.
Missing signing configuration, failed signing, rejected notarization or failed
Gatekeeper assessment stops packaging. No fallback preview is labelled a release.

## Review before publishing

1. Verify the ZIP checksum and unpack it into a new folder.
2. Install the signed app in `/Applications`, approve Accessibility, and test VNI,
   Telex, ABC, shortcuts and remembered language with a physical keyboard.
3. Test login on/off, any required approval in System Settings, then an actual
   logout/login. Check that launching again does not silently re-enable login.
4. Test update installation over the prior signed version, retained preferences
   and Accessibility access. The app opens VinaKey Releases; replacing the app is
   explicit and there is no background installer or upstream OpenKey updater.
5. Test sleep/wake, Spotlight, secure input, app rules and clipboard conversion.
6. Review the signed/notarized archive, manifest and notes before publishing a
   GitHub release at `vinadesignstore/vinakey`. A tag alone does not publish it.

Without a Developer ID certificate, signed installation/update testing and
notarization remain unverified. Do not publish the local preview as a stable
release. The package script does not create tags, releases or upload assets.

Platform references: [Apple login services](https://developer.apple.com/documentation/servicemanagement/smappservice),
[Apple notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
