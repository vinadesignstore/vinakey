# VinaKey engine validation log

Milestone checkpoints and live/computer-use test results, kept as written at each checkpoint. Automated checks are described in [README.md](README.md).

## Review checkpoint

The draft includes the Rust engine, milestone 3 reliability work and milestone 4 menu-bar/settings simplification. Milestone 5 has not started. Updater repair, login-item API migration, signing/notarization and release verification remain deferred. Automated native checks do not establish physical typing compatibility.

## Milestone 3 reliability checkpoint

`sh scripts/check-macos-input.sh` tests the actual native callback and manager with event posting intercepted and a local Mach port (no global keyboard input):

- Timeout notification dispatch and automatic recovery; explicit user/system disable stays paused.
- Invalid port recreation without reinitializing the engine; permission revocation and stop release the tap/timer.
- Secure input prevents recovery and bypasses composition.
- Replacement events preserve the original target PID and serial number.
- An external private event source composes VNI `a1` into `á`, while OpenKey’s own private-source events are ignored.
- Spotlight selection replacement requires the event target to match Spotlight, preventing a fading window from changing another app’s editing strategy.
- Terminal apps bypass the empty-character browser workaround; empty encoding-length tracking never dereferences `vector::back()`.
- Rust field resets discard word, macro and editing history while preserving stored macros and application settings.

The tap retains the established session location. Context/source changes refresh cached app and keyboard-language data outside the keystroke callback, and the copied keyboard source is released without releasing its borrowed properties.

Live testing on macOS 27.0: the app launches after reapproving the local build and its event tap is present and enabled. Computer-use `pressKey`/`typeText` produced literal VNI `a1`/`vie65t` and Telex `as` in TextEdit; the cause has not been established, so automated live composition is **not marked passed**. The user confirmed physical VNI `a1` produces `á`. macOS also has ABC and VNI input sources installed; the active source was not established, so that observation alone does not isolate Rust engine behavior.

Additional milestone 3 computer checks:

- **Passed, hook lifecycle only:** after user-confirmed sleep/wake, the same OpenKey process (PID 2039) had a new enabled tap (2143124030 before, 1988714904 after). No app restart was needed. Injected `a1` remained literal after wake; composition recovery is still unverified.
- **Passed, native editing only:** pasted `tiếng Việt` supported backspace and cursor insertion/deletion, restoring the original text. TextEdit search-field input stayed in the field and left the document unchanged. These checks do not verify Rust composition across field boundaries.
- **Inconclusive:** Spotlight did not visibly open through computer-use Command-Space, even after temporarily enabling its disabled shortcut with user approval. The shortcut was restored to disabled and verified. Spotlight dismissal/typing routing remains unverified.
- **Blocked:** the computer-use tool denied Terminal access; no alternate route was used. Remote-desktop input remains untested.

VNI, Unicode, Option-Z, smart switching and browser-workaround settings were restored. The live-authorized app was `OpenKey.app`; it predates the final explicit-pause-on-wake adjustment. That adjustment has native lifecycle coverage, but the final review artifact still needs a live run. Those results remain a draft checkpoint, not a merge-ready live-validation claim.


## Milestone 5 local release candidate

The fork now uses version 0.1.0 (1), deployment target macOS 12 and hardened runtime. The upstream development team is removed. Login-at-startup uses SMAppService.mainAppService on macOS 13+, reports registration failures/required approval and reads the OS status instead of trusting a saved toggle. App launch does not silently register a login item. On macOS 12 the toggle is disabled; users can add the app through system Login Items.

The inherited network updater and replacement-helper code are removed. All update commands open VinaKey Releases for an explicit download; there is no automatic installer. `scripts/package-macos.py` builds a staged universal app and produces an archive, checksum and manifest. Preview mode uses an ad-hoc signature. Release mode requires an installed Developer ID Application identity and Keychain notary profile, secure timestamp/hardened runtime, Accepted notarization, stapling and Gatekeeper assessment before producing a release archive. See `RELEASE.md`.

Native regression checks cover login enable/disable, idempotent registration, failed registration and required approval without changing real system login items. The existing engine/input/settings/menu checks pass. A macOS CI workflow performs the same checks and packages a clearly labelled local preview.

No valid Developer ID identity is installed. The user selected a local candidate plus signing instructions. Actual login/logout, signed upgrades, notarization and Gatekeeper acceptance remain unverified; no public binary release or tag has been created. Earlier computer-use results below apply to the prior artifact, not this candidate.

## VinaKey fork checkpoint

The macOS product is now **VinaKey** (`com.vinadesignstore.vinakey`), published separately at `vinadesignstore/vinakey`. Source paths, engine ABI and Xcode scheme retain their historical names; Windows/Linux remain inherited OpenKey source. Original copyright/license notices are preserved in source, LICENSE and NOTICE.md.

Current tabs are **Chung**, **Gõ tiếng Việt**, **Ứng dụng** and **Giới thiệu**. Compatibility controls are a described section inside Chung. Every option has explanatory text. The status menu uses **ABC** and solid EN/VI template badges with transparent letter cutouts. About shows VinaKey/version and repository/license links; the previous introductory credit paragraph is removed. Clipboard conversion is a compact native sheet with a standard Close/Convert footer. Automatic upstream OpenKey update checking is disconnected; the update command opens VinaKey Releases. No release updater/signing workflow was added.

The universal VinaKey build and native checks pass, covering the merged controls, About navigation, compact sheet dimensions, ABC selection and rasterized badge fill/letter cutouts. The VinaKey artifact at `VinaKey.app` was computer-tested after the user approved Accessibility access for its separate identity:

- The branded permission gate blocked Settings until approval. The real About tab showed VinaKey/version without the removed credit paragraph.
- All four tabs opened. General displayed the merged compatibility section and descriptions; Chromium toggle/restore passed. Typing switched Telex → VNI → Telex, and turning spelling off disabled restoration until spelling was restored.
- The compact conversion sheet rendered complete pickers/help and standard footer buttons. Unicode → VNI Windows → Unicode selection, the no-text-clipboard alert, alert dismissal and Escape to close all passed. Conversion of actual clipboard text was not exercised; the user clipboard was not replaced.
- A disposable TextEdit rule was added, changed to ABC and removed. Original OpenKey preferences matched their pre-test snapshot exactly. Tested VinaKey controls were restored (Telex, Unicode conversion, Chromium off, spelling on); the new app initialized its own preferences.
- A clean restart retained Option-Z and showed an enabled event tap. The app remains running for review.

The status dropdown/badge remains unavailable to this computer-control surface, so ABC menu switching, solid-badge appearance and menu/settings visual synchronization are not marked as live passes. Native menu/raster tests cover them. Physical typing and the complete remembered-language/app-switch sequence remain unverified on VinaKey. Historical live results below apply to their named OpenKey artifacts only. Milestone 5 remains deferred.

## Historical milestone 4: OpenKey native menu-bar app

The menu-bar app has four native toolbar settings tabs: **Chung**, **Gõ tiếng Việt**, **Ứng dụng** and **Tương thích**. AppKit owns the window/toolbar; SwiftUI grouped forms provide content on macOS 13+, with an AppKit fallback on older systems. There is no sidebar/search or Advanced Settings route.

- General contains login, the accessible language-shortcut recorder and its sound option. Recording preserves the saved sound flag and ends on focus loss, close or permission revocation.
- Typing exposes input method, encoding, spelling/restoration, extra consonants, accent placement, sentence capitalization, quick consonants and temporary Control/Command bypass behavior.
- Applications is a full tab containing language/encoding remembering and fixed/remembered app rules. Fixed rules constrain shortcut/menu language changes. App pickers attach to the settings window.
- Compatibility exposes browser suggestions, Chromium, separate key delivery, keyboard layout and bypass with another macOS input method. Existing saved values are preserved.
- Text Replacements has no UI or route in OpenKey: no link, editor, import or export. OpenKey macro expansion remains disabled; old macro data is retained without modification. macOS owns text replacement and Fn/Globe behavior.
- Missing Accessibility permission gates settings entirely. Approval connects input and dismisses setup; revocation restores the gate. A contextual menu command handles paused/failed connections.
- The native status menu offers English, Telex, VNI, Simple Telex 1 and Simple Telex 2, with exactly one checked choice. The menu bar shows an outlined EN/VI badge and the active name. Selecting a Vietnamese style saves the style and enables Vietnamese; English preserves the last style. Fixed-English rules block Vietnamese entries; fixed-Vietnamese rules allow style changes but block English. Language changes also remain available through the shortcut. Conversion remains an optional sheet; About is native. New/reset installs leave login/remembering off; existing preferences remain.
- Remembered-language saves resolve the current app and its rule together, including explicit remembered rules with global remembering off. Settings activation does not implicitly overwrite the typing app's choice.

### Validation and review limits

`sh scripts/check-macos-input.sh` covers the native callback, lifecycle, actual AppDelegate menu actions and isolated settings. The updated settings check exercises four-tab navigation, restored typing/compatibility preferences, encoding, preserved shortcut sound, app-rule persistence, the permission gate and absence of Text Replacements entry points. Menu checks exercise all style selections, status badges/names/checkmarks, persisted language/style, English preserving the last style, fixed-English/fixed-Vietnamese policy and disabled input when permission/tap is unavailable.

The previous two-pane artifact was computer-tested: permission gate/approval, both panes, VNI → Telex → VNI, spelling dependencies, shortcut recording, app-rule add/change/remove, native About, Command-Comma and utility sheet layouts. It restarted with an enabled keyboard tap. Tested preferences, macro bytes and remembered data were restored. The native macOS replacement import/expansion test passed and its disposable entry was removed, preserving the original 10 replacements; this integration is now removed from OpenKey.

The latest four-tab/input-menu revision is a separate artifact at `OpenKey.app` with matching zip. It is built for arm64/x86_64, locally ad-hoc signed and not notarized. It was live-authorized after replacing the stale permission record. Computer use selected Telex, Simple Telex 1, Simple Telex 2 and VNI through the real Settings picker, opened/cancelled the Applications picker, toggled/restored Chromium compatibility and inspected all four tabs. A clean restart showed the original Option-Z shortcut and an enabled event tap. Preference comparison matched the original snapshot except SettingsPane; original macro and remembered-app data were preserved. The previous artifact was closed.

The status dropdown remains unverified live: even after the user manually opened it, computer control returned only the settings window and could not expose the dropdown/badge. System menu surfaces timed out. The actual AppDelegate menu actions/checkmarks/badge names remain covered by native tests, not a claimed computer-use pass. Physical composition and settings-to-status-menu visual synchronization were not established by this session. Older macOS fallback remains untested at runtime.

The complete physical remembered-language shortcut/app-switch/typing regression remains unverified. Earlier physical fixed-English/fixed-Vietnamese results apply to an older artifact; injected computer input bypasses the OpenKey tap and is not a physical pass. Earlier sleep/wake established tap recreation only. Live Spotlight composition, secure input and remote desktop remain unverified; computer control denied Terminal access.

Stop for review before milestone 5: updater repair, login-item API migration, signing/notarization and release verification have not started.
