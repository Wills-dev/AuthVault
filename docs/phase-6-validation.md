# Phase 6 validation — 30 October 2026

This record distinguishes executed passes, expected unsigned-artifact rejection,
failed attempts and resolved validation blocks. **The final real native full-flow
retest passed with manual sensor input. Phase 6 audit validation is complete.**
Production readiness remains blocked by the open risks; Phase 7 has not started.

## Environment and safety boundary

Flutter 3.47.9 / Dart 3.13.7, Node 24.22.1, NestJS 12.3.2, Prisma 7.10.1 and
local PostgreSQL 17.10. Android SDK Platform 36 / Build Tools 36.0.0; target
`emulator-5554`, Android 17 API 37 arm64. Android Studio's bundled JDK is required
for apksigner on this host; `java` on PATH has no configured runtime. iOS/Xcode and
CocoaPods remain unavailable. No production service, account or secret was used.

Backend tests insist on `authvault_test`, migrate only that isolated DB, create
owned fixtures and clean fixture data. The application DB is local `authvault`;
schema/status/drift checks there are read-only except prior existing migrations.
Performance fixtures use owned software EC keys and real local SMTP, explicitly
not native biometric evidence. No production rate limits or accounts were modified.

## Executed checks

| Check | Result |
| --- | --- |
| Baseline Flutter suite | Passed: 78 tests before added audit regressions |
| Baseline backend compile/tests | Passed: 8 unit + 37 integration = 45 tests |
| New logout/delete and initial-read regressions before fixes | Failed as expected; original behavior reproduced |
| New stale invalid-session cleanup regression before fix | Failed: newer saved refresh was erased |
| `dart format .` | Passed; final no-change check: 50 files, 0 changes |
| `flutter analyze` | Passed after fixing one audit-driver style diagnostic; no issues |
| `flutter test --coverage` | Passed: **87 tests** |
| `npm run lint` / `npm run build` | Passed |
| `npm run test:coverage` | Passed: **69 tests in 6 suites** (21 unit, 48 integration) |
| Backend coverage | **99.45% lines (1647/1656), 83.74% branches (371/443)** |
| Flutter reported LCOV coverage | **76.84% lines (753/980); branch coverage not collected** |
| `npm run format:check` | Passed |
| Prisma validate/status/drift | Valid schema, 3 applied migrations, no drift; Phase 6 adds no migration |
| `npm audit --omit=dev --json` | No known runtime advisories reported |
| Full `npm audit --json` | Six Low package entries from one deepmerge advisory; unresolved, no breaking downgrade applied |
| OSV Pub lockfile audit | 81 hosted package versions queried; no advisory matches returned |
| Android debug build | Passed; clean sequential rebuild passed in 25.8 seconds |
| Android release build | Unsigned audit compilation passed; clean sequential rebuild passed in 45.9 seconds |
| Release signing inspection | Unsigned APK rejected by apksigner as expected; no debug identity fallback |
| Release manifest/resources | Cleartext false, backup false, extraction rules retained, debug network policy absent |
| Native cancellation integration | Passed: actual prompt cancellation, no signature; 4 seconds excluding build/install |
| Complete Android MFA after remediation | **Passed** with user-triggered enrolled fingerprint input; 29-second scenario |
| Normal-entrypoint debug app after integration | Rebuilt in 11.9 seconds, launched with exit 0, focused signed-out login visually verified |

Coverage details/exclusions: [test-coverage.md](test-coverage.md). Raw aggregated
[evidence](evidence/phase-6/coverage-summary.json). Backend line counts include V8/
ts-jest structural lines; neither percentage implies exhaustive attack coverage.

## Security and reliability cases actually executed

Existing real HTTP/PostgreSQL suites continue to cover wrong passwords, forged/
altered/expired/replayed/cross-user/concurrent biometric proofs; invalid/reused/
expired/cross-attempt OTPs, cooldown/replacement/exhaustion/quota/concurrent use;
SMTP rejection/accepted replacement; pending-Bearer denial; successful token issuance;
refresh rotation, replay and concurrent family revocation; logout JWT reuse and
expired sessions. New cases add manipulated stage/client-state fields, unsigned and
wrong-key JWTs, login unknown-user equivalence, confirmed signup enumeration,
spoofed forwarded-IP quota attempts, cross-account query selectors, mismatched JWT
subject/session, credential revocation after completion, and security/CORS headers.

Flutter fixtures verify failed deletion still attempts server revocation; immediate
logout during initial read; stale refresh and invalid-session cleanup cannot erase
newer credentials; serialized refresh; failed secure persistence; network failure/
recovery; expiry and navigation; safe errors and debug-preview policy. Four automated
accessibility checks cover Android targets, actionable labels and text contrast.
Large-text/keyboard/responsive tests include 320×568 and 568×320 protected layouts.
No layout overflow was reported in the passing widget suite. This is not a full
screen-reader or physical-device accessibility assessment.

## Android native attempts and final successful retest

```sh
flutter drive --driver=test_driver/password_auth_driver.dart --target=integration_test/native_biometric_cancel_test.dart -d emulator-5554
flutter drive --driver=test_driver/phase_6_mfa_driver.dart --target=integration_test/full_mfa_test.dart -d emulator-5554
```

Cancellation passed with a real Android Keystore key/prompt and asserted CANCELLED,
not a synthetic authenticated response. The full-flow attempt then registered an
owned account but timed out waiting for enrolment completion. A retry using the
previously documented `--no-enable-impeller --enable-software-rendering` flags also
failed at that transition. Safe UI diagnostics showed the account-created context;
there was no fabricated signature, OTP or authenticated session.

Android biometric diagnostics reported sensor state 4 with no CurrentSession after
those attempts. This is observed platform metadata, not a proven application root
cause. The guest was rebooted **without wiping AVD data**. Initial boot did not
complete within the bounded wait. A premature subsequent launch returned Android
activity-not-found. Once boot completed, Android reported RUNNING_LOCKED and rejected
the existing private local test PIN as a mismatch. Further attempts were stopped;
the PIN was not printed, guessed, changed or cleared. The user was asked to unlock
`emulator-5554` manually, without sharing their PIN.

The user subsequently confirmed unlock. Android now reports RUNNING_UNLOCKED, and
installation/launch succeeded. The resumed run reached a real biometric prompt;
Android rejected virtual fingerprint 1. A controlled retry with virtual fingerprint 2
was also rejected. The app displayed “Biometric authentication failed. No proof was
accepted,” and fixture attempts remained PENDING_ENROLMENT. Fingerprint diagnostics
report two enrolled prints and rejected CryptoObject authentication. No OTP/session
success was fabricated. Sensor state 4 was again observed after cancellation; that
alone does not establish a framework defect or explain a mismatched virtual print.

### Final manual retest — passed

After confirming readiness, the user supplied their enrolled virtual fingerprint
through emulator controls during both native prompts. The complete scenario passed
in **29 seconds**, excluding its 20.8-second build and 3.5-second installation:

```sh
AUTHVAULT_TEST_FINGERPRINT_ID=manual flutter drive --dart-define=MANUAL_BIOMETRIC_TEST=true --no-enable-impeller --enable-software-rendering --driver=test_driver/phase_6_mfa_driver.dart --target=integration_test/full_mfa_test.dart -d emulator-5554
```

The run executed registration → Android Keystore enrolment/signature → password
login → native biometric signature/server verification → actual SMTP acceptance and
mailbox receipt → deliberately wrong OTP rejection → actual delivered OTP verification
→ authenticated account/dashboard data → secure-storage restoration through refresh
rotation → profile → logout → protected-route denial. No accepted code or API success
was hardcoded. Backend fixture state reached COMPLETED; the test asserts logged-out
state and dashboard denial afterward.

Manual mode disables automatic virtual-finger events. The harness permits a
110-second wait for each biometric transition with the test-only Dart define;
automated mode retains 60 seconds. The server's 120-second challenge expiry and
signature requirements are unchanged. Earlier wrong-ID failures and a manual-input
timeout remain failed runs; they are not converted to passes. The successful run
used the documented emulator-only Skia software-rendering flags. No production
Android rendering policy or native authentication code was weakened.

Captured and visually inspected [OTP issued](images/phase-6/otp-issued.png),
[real dashboard](images/phase-6/dashboard.png) and [real profile](images/phase-6/profile.png).
The OTP capture precedes entry and contains no code. Long fixture email text wraps
within its card; no overflow was observed. Values are actual local backend fixture
data, not preview activity. [Native evidence](evidence/phase-6/native-evidence.json)
contains no credentials or OTPs. Hardware backing was reported **false**; this is
emulator OS/signature evidence, not physical hardware or real-person biometric proof.

The Phase 5 full flow remains historical and is not counted as the new Phase 6 pass.
Provider-container recreation with real secure storage is tested; an OS-kill/reboot
restoration experiment of a live authenticated session is not claimed. Native line/
branch coverage, real-world biometric accuracy and iOS remain unmeasured.

## Builds and artifact inspection

```sh
flutter build apk --debug
flutter build apk --release --dart-define=API_BASE_URL=https://api.authvault.invalid/v1
```

The first debug build passed in 12.7 seconds and initial unsigned release build in
95.0 seconds (52.8 MB audit artifact). After a later integration attempt overlapped
build preparation, a repeat release compile found a stale generated registration
for the dev-only integration_test plugin. That run failed and is not counted as a
pass. Generated outputs were cleaned with `flutter clean`, dependencies restored
with `flutter pub get`, and debug/release rebuilt sequentially. Generated plugin
source was not hand-edited and no production dependency was added to hide the issue.

The release URL is reserved `.invalid`, not an operational endpoint. No real release
key or credentials were introduced. Absence of release signing properties now means
unsigned output; apksigner's expected rejection is not a successfully signed release.
Compiled manifest/resources show cleartext and backup disabled and no debug network
configuration. Release preview policy is covered by static compile-time branches and
unit policy tests; an unsigned release binary was not installed for interactive UI
or hardware-biometric validation. Native hardware enforcement cannot be established
by the emulator. Gradle/JDK native-access and Cupertino font tree-shaking warnings
were nonfatal in the passing builds; no unused font dependency was added just to
silence a build warning.

The normal `lib/main.dart` debug app was rebuilt after integration (11.9 seconds),
then launched with the same emulator-only rendering flags. The command exited 0,
Android window inspection confirmed the AuthVault activity was focused, and its
[signed-out login screen](images/phase-6/normal-app-launch.png) with empty fields was
visually inspected. The integration-test entrypoint was not left as the normal app.

## Performance and readiness

Five measured server-flow samples: median **390.90 ms** for the fixture's complete
server MFA sequence; **8.86 ms** OTP verification, **5.34 ms** refresh and **2.65 ms**
account read. These include local HTTP/test instrumentation, exclude humans/native
biometrics and are not production promises or improvements. Sample size is five;
[p95 and resource methodology](performance-evaluation.md) explains its limits.

Readiness remains **not production ready**, particularly remote biometric attestation,
owned distribution identity, signup/recovery, retention, TLS/SMTP operations, backups,
monitoring and physical/iOS evidence. [Audit](phase-6-security-audit.md) contains
confirmed findings, remediation and open risks. No Critical unauthorized-account
MFA bypass was found in the tested local scope; the High software-key biometric-
assurance gap remains explicitly confirmed and unresolved.

## Reproduce remaining and completed checks

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
cd backend
npm run format:check
npm run lint
npm run build
npm run test:coverage
node scripts/summarize-phase6.mjs
npm audit --omit=dev
npm audit
node scripts/audit-pub.mjs
npx prisma validate
npx prisma migrate status
npx prisma migrate diff --from-config-datasource --to-schema prisma/schema.prisma --exit-code
```

Use documented local setup and isolated test DB; keep mailbox/credentials private.
From repository root with an enrolled sensor ready, run the full-flow driver command
above. If emulator rendering again requires the documented flags, record that
condition and actual result. Rebuild the normal app after integration entrypoints.

Final clean sequential builds passed: debug **25.8 seconds**, unsigned release
**45.9 seconds**, release size **52.8 MB**. Final formatting checked 50 files with
zero changes; analysis reports no issues. The rebuilt release inspection is saved
in [android-artifacts.json](evidence/phase-6/android-artifacts.json). The final manual native full-flow pass and its operator/rendering conditions are
recorded above; earlier failed attempts remain in the record.
