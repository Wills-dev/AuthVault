# AuthVault

A Flutter/Dart and planned NestJS/PostgreSQL academic MFA prototype. Intended flow:
password → biometric-protected challenge signature → email OTP → protected dashboard.

**Phases 1 and 2 are implemented.** Welcome, login, registration, device-readiness
and email-code screens are available. Dashboard/profile designs live in a labeled
debug-only gallery: choose **Development UI preview** from welcome. There is no
backend, authenticated session or simulated successful login. Normal protected
routes redirect to login. Phase 3 requires explicit approval.

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
Phase 4 will configure Face ID usage text, secure key entitlements, Android native
prompt integration and device-specific deployment requirements. Generated platform
identifiers and debug release signing are placeholders; configure owned identifiers
and release signing before distributing a build.

PostgreSQL, its client and Docker are not installed. Install PostgreSQL directly or
use Docker for the Phase 3 database. Backend setup will supply an `.env.example`
with DATABASE_URL, signing/HMAC secrets and SMTP settings, committed migrations and
seed instructions. No database or email service is needed to run Phase 1. Never
commit `.env` files or real secrets. Do not place backend secrets in Dart defines.

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
suggests a commit and stops for approval. Next: Phase 3 backend registration and password login, followed by native signing,
OTP, sessions and full evaluation.

Known limitations: no real MFA yet; iOS toolchain incomplete; database unavailable;
real-device biometrics untested; account recovery and device attestation remain
explicit design limitations. No academic evaluation results are fabricated.
