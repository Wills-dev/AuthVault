# AuthVault

A Flutter/Dart and planned NestJS/PostgreSQL academic MFA prototype. Intended flow:
password → biometric-protected challenge signature → email OTP → protected dashboard.

**Phases 1–5 are implemented; Phase 6 audit and hardening are complete.** Registration and password authentication use
NestJS/PostgreSQL. Android Keystore signatures prove device biometric authorization;
SMTP email OTP completes MFA before access and rotating refresh credentials are issued.
The protected dashboard retrieves real account/security data. Debug previews remain isolated.

Android emulator checks establish OS prompt/signature behavior, not physical hardware
backing. iOS signing, recovery and server-side hardware attestation remain unimplemented.
See [Phase 5 architecture and security](docs/phase-5-implementation.md) and
[actual validation results](docs/phase-5-validation.md). Phase 6 audit and successful manual native MFA retest are recorded below. Phase 7 requires approval.

## Setup

The inspected environment on 29 October 2026 has Flutter stable 3.47.9, Dart 3.13.7,
Node 24.22.1 and npm 11.19.1. Use this Flutter version for reproducible checks;
`pubspec.lock` records exact package resolutions. Run from the repository root:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter run -d emulator-5554
```

Run `flutter devices` to choose an available target. Android SDK 36.0.0 tooling and
an API 37 emulator were detected. Flutter Doctor finds and uses Android Studio's
bundled OpenJDK 25 even though `java` on PATH has no configured runtime.
Android SDK Platform 36, Build Tools 36.0.0 and NDK 28.2.13676358 are verified
installed. The follow-up `flutter build apk --debug` succeeded, and the resulting
APK was installed and launched on `emulator-5554`. The current Phase 2 UI was also
built, launched and visually inspected; see Phase 2 validation below. No Gradle or application changes were necessary. See the
[validation record](docs/phase-1-validation.md) for commands, timings and warnings.
This debug emulator smoke check does not validate biometric security.

For iOS install full Xcode, select its developer directory, run its first-launch
setup, and install CocoaPods as required by native plugins. This machine currently
has only Apple command-line tools; iOS builds cannot yet be validated. Then run
`flutter doctor -v`, select an iOS simulator/device and `flutter run -d <device>`.
iOS secure-key signing, Face ID configuration and entitlements remain future work.
Phase 4 implements native Android signing only. Generated platform
identifiers and debug release signing are placeholders; configure owned identifiers
and release signing before distributing a build.

The Phase 3 backend setup is in [backend/README.md](backend/README.md), including
exact PostgreSQL installation/fallback commands, generated local credentials,
migrations, server startup and isolated database tests. PostgreSQL 17.10 was
provisioned locally for validation; Docker remains unavailable. Never commit .env
files or real secrets.

Start the backend before submitting a mobile form. Android debug defaults to
http://10.0.2.2:3000/v1. Override centrally when needed:

```sh
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000/v1
```

Release builds must configure an HTTPS URL ending in /v1. Local HTTP exceptions
exist only in the Android debug manifest/resource overlay.

## Decisions and structure

Flutter stays at the root; `backend/` reserves the NestJS boundary, and `docs/`
holds design and security contracts. See [architecture](docs/architecture.md),
[draft API](docs/api-contract.md), [dependency decisions](docs/dependencies.md) and
[evaluation methodology](docs/evaluation.md).

Material 3 uses navy, white and restrained teal, shared spacing/radius tokens,
48 logical-pixel button targets, native typography and scrollable safe-area layout.
System text scaling is retained. No custom fonts or decorative image dependencies
are needed. Riverpod owns DI; GoRouter owns navigation; network and security
plugins are installed for later phases but do not imply implemented security.

## Validation and workflow

Phase 2 adds widget checks for forms, navigation, error/loading states, OTP paste,
biometric readiness and protected routes, including large-text/keyboard layouts.
See [Phase 1 validation](docs/phase-1-validation.md),
[Phase 2 notes](docs/phase-2-implementation.md),
[navigation](docs/navigation.md) and [Phase 2 results](docs/phase-2-validation.md).

Capture emulator screenshots and run the screen inspection:

```sh
flutter drive --driver=test_driver/ui_gallery_driver.dart --target=integration_test/ui_gallery_test.dart -d emulator-5554
```

The driver captures images in `docs/images/phase-2/`; its capture callback does not
assert pixel equality. Inspect images separately. Build/run the normal app afterward
because the inspection uses an integration-test entrypoint.

Each subsequent phase updates documentation, runs applicable checks, fixes failures,
suggests a commit and stops for approval. Phase 6 has not started.

Known limitations: production inbox delivery and physical devices remain unvalidated; iOS toolchain incomplete;
real-device biometrics untested; account recovery and device attestation remain
explicit design limitations. No academic evaluation results are fabricated.


Phase 3: [implementation/security notes](docs/phase-3-implementation.md),
[API contract](docs/api-contract.md), [validation](docs/phase-3-validation.md).
With the backend running, execute the real emulator integration:

```sh
flutter drive --driver=test_driver/password_auth_driver.dart --target=integration_test/password_auth_test.dart -d emulator-5554
```

The integration generates random fixture credentials, verifies pending-only
registration/login, and confirms the dashboard guard. It does not convert rendering
surfaces or capture screenshots. It creates one local test
account; its MFA attempts are revoked at the end. Rebuild the normal app after
running integration entrypoints.


Phase 4: [implementation](docs/phase-4-implementation.md),
[security design and sequence](docs/biometric-security-design.md),
[validation](docs/phase-4-validation.md).
Configure a strong fingerprint in Android Settings before native checks. The host
finger-event driver is test tooling only; the app always uses a real native prompt
and the server always verifies signatures:

```sh
flutter drive --driver=test_driver/password_auth_driver.dart --target=integration_test/native_biometric_cancel_test.dart -d emulator-5554
flutter drive --driver=test_driver/biometric_auth_driver.dart --target=integration_test/biometric_auth_test.dart -d emulator-5554
```

The second command feeds virtual fingerprint 1 to Android's emulator sensor. It
requires that fingerprint to be enrolled in the OS. No successful authentication
response is hardcoded in the app. These tests do not measure real biometric error
rates or establish TEE/StrongBox protection. Rebuild the normal app after test entrypoints. Phase 5 connects the OTP screen to SMTP-backed verification.

The emulator setup created its first screen-lock PIN and fingerprint 1 for native
validation. The generated test PIN is kept only in ignored local tooling at
backend/.local/emulator-test-pin; it is not an AuthVault password or app fallback.
Do not commit or print that file. No existing emulator PIN was replaced.


## Phase 5: email OTP and sessions

In `backend/`, update an existing development `.env` safely, migrate, and run a
controlled SMTP mailbox in a separate terminal:

```sh
node scripts/configure-local-auth.mjs
npm run generate
npm run db:migrate
node scripts/mailbox.mjs
```

Then `npm run build && npm start`. The mailbox accepts SMTP on loopback 1025 and
exposes test messages only at `http://127.0.0.1:8025/messages`. This is private local
test tooling, never an app API. Alternatively use Mailpit; see the backend README.
The emulator test below specifically uses the bundled mailbox API.

```sh
flutter drive --driver=test_driver/full_mfa_driver.dart --target=integration_test/full_mfa_test.dart -d emulator-5554
flutter build apk --debug
flutter run --debug --no-resident -d emulator-5554 --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk
```

The E2E test registers random credentials, authorizes native biometric signatures,
reads its real SMTP-delivered code from the controlled mailbox, exercises wrong-code
rejection, completes MFA, retrieves the dashboard, rotates saved credentials and
logs out. It never hardcodes an accepted code or fabricates API authentication.
See [Phase 5 validation](docs/phase-5-validation.md) for executed results and limits.


On this API 37 emulator, a post-reboot System UI/rendering failure required an
emulator-only launch diagnostic with `--no-enable-impeller --enable-software-rendering`.
The normal welcome screen was visually verified with those flags; the full MFA E2E
had passed with the default renderer. No Android project configuration was changed.
See the [validation record](docs/phase-5-validation.md) for the exact distinction.


## Phase 6: security review and readiness

The audit preserves the application architecture and adds security regression,
coverage, performance and accessibility evidence. Release builds no longer fall
back to the debug signing identity; without owned signing properties they are
unsigned audit artifacts. Logout/restoration and stale secure-storage write races
are hardened, and Android backup/transfer exclusions are explicit.

**Not production ready:** remote biometric attestation is absent, so a modified
client can enrol/sign with a software key. Registration still exposes duplicate
email status. Operational TLS/SMTP, retention, backups, monitoring, owned distribution
identity, physical devices and iOS remain gates. Runtime npm audit reports no known
advisories; six Low development-tool dependency entries remain unresolved.

Phase 6 native cancellation and the complete post-remediation MFA scenario passed.
The final flow used manual enrolled-fingerprint input and the documented emulator
rendering workaround, then real SMTP OTP, authenticated dashboard/profile, secure
session restoration and logout. The scenario completed in 29 seconds excluding
build/install. The normal app was rebuilt and its signed-out screen visually verified. Wrong virtual-finger attempts and earlier timeouts remain recorded
as failures. No real-person biometric accuracy or hardware attestation is claimed.

- [Security audit and risk register](docs/phase-6-security-audit.md)
- [Actual validation results](docs/phase-6-validation.md)
- [Threat model](docs/threat-model.md)
- [Line and branch coverage](docs/test-coverage.md)
- [Measured performance and limits](docs/performance-evaluation.md)
- [Production readiness and deployment gates](docs/production-readiness.md)

```sh
flutter test --coverage
cd backend
npm run test:coverage
node scripts/summarize-phase6.mjs
node scripts/audit-pub.mjs
```

No production deployment or Phase 7 work was performed.
