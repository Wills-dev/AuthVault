# Phase 4 validation — 30 October 2026

## Executed results

| Check | Actual result |
| --- | --- |
| Incremental Prisma migration | Passed against authvault and isolated authvault_test |
| Prisma validate / migrate status | Passed; schema valid, database up to date, two migrations |
| Backend formatting / ESLint | Passed |
| Backend strict compilation | Passed; test-source no-emit type check also passed |
| Backend unit tests | 8 passed |
| Backend HTTP/PostgreSQL integration tests | 22 passed (10 existing + 12 biometric cases, including parameterized concurrency cases) |
| Flutter formatting | Passed: final scoped check covered 41 Dart files, no changes |
| Flutter analyze | Passed: no issues found |
| Flutter automated tests | 62 passed |
| Real Android prompt cancellation | Passed, one test body plus teardown; repeated after lifecycle fix |
| Real Android enrolment + biometric login | Passed, one test body plus teardown; repeated after lifecycle fix |
| Normal Android debug APK | Passed: flutter build apk --debug, final assembleDebug 13.5 seconds |
| Normal emulator launch | Passed: flutter run exited 0, foreground/process/rendered welcome confirmed |
| Physical Android hardware security | Not tested; emulator key reports no hardware backing |
| iOS secure biometric signing / build | Not implemented or tested in Phase 4 |
| Email OTP / completed authenticated session | Not implemented; Phase 5 has not started |

No mocked biometric test is counted as hardware security evidence. No genuine-user
success rate, impostor rejection rate or production response-time measurement is
claimed. Tooling durations below are debug-emulator observations only.

## Environment and native setup

Used Flutter 3.47.9 / Dart 3.13.7, Node 24.22.1, PostgreSQL 17.10 and the existing
Android 17 / API 37 arm64 emulator emulator-5554 (Medium_Phone_API_37.0).
The previously working SDK/NDK and networking configuration were preserved.
AndroidX Biometric 1.1.0 was added explicitly for stable CryptoObject integration;
MainActivity now extends FlutterFragmentActivity with an AppCompat normal theme.

Initial fingerprint-service inspection showed one sensor and zero enrolled prints.
Android's enrolment UI offered its first screen lock. A randomly generated test
PIN was set using cmd lock_settings, stored only in ignored local tooling with
mode 0600, never printed, and confirmed through Android's secure screen. No existing
PIN was replaced. The older lock_settings binary was absent; the supported cmd
interface succeeded. Fingerprint 1 was then enrolled through Android settings using
virtual sensor events. Android confirmed Fingerprint added and sensor count 1.
This is an OS emulator fingerprint, not a real person's biometric template.

## Native cryptographic evidence

Executed successfully:

```sh
flutter drive --driver=test_driver/password_auth_driver.dart --target=integration_test/native_biometric_cancel_test.dart -d emulator-5554
flutter drive --driver=test_driver/biometric_auth_driver.dart --target=integration_test/biometric_auth_test.dart -d emulator-5554
```

The cancellation test creates/loads an actual AndroidKeyStore key, initializes a
Signature CryptoObject, displays the OS biometric prompt, then cancels without
feeding any successful fingerprint event. It asserted CANCELLED and no signature.
The final repeated run's test body reported about 15 seconds.

The full integration uses real Flutter registration/login forms and the running
backend. It creates the device key, requests an enrolment challenge, signs through
the OS prompt and waits for backend ENROLMENT_COMPLETE before returning to login.
A new password attempt obtains a fresh login challenge; the existing device key
signs through another OS prompt, the backend verifies it, and Flutter reaches
PENDING_OTP. The test asserts the dashboard still redirects to login and revokes
the pending attempt at the end. No code is sent or verified. Random local fixture
accounts and their public credentials remain in the development database.

The host-only driver feeds virtual fingerprint 1 events to Android's emulator
sensor. It does not inject an authentication result, signature or successful API
response into the application. Native checks require non-exportability through
the KeyStore API, authentication-per-use and enrolment-change invalidation before
returning public metadata. The final repeated full-flow test body reported about
43 seconds; the earlier run also passed. See the sanitized
[native result summary](phase-4-native-evidence.json).

After these runs, Android's fingerprint service reported one enrolled print,
acceptCrypto=4 and acquireCrypto=4, with no ordinary non-crypto accepts. These are
cumulative emulator diagnostic counters from two successful enrolment/login runs,
not biometric accuracy measurements.

The actual key metadata reported hardwareBackedReported=false. The emulator runs
AndroidKeyStore software backing with per-use OS biometric restriction in debug.
It does not establish TEE/StrongBox protection or resistance to physical extraction.
Non-debug native operations reject keys reported as not hardware-backed, but no
physical/release-device test was performed. There is no server hardware attestation
validation; read biometric-security-design.md for the explicit trust assumption.

## Server security tests

Real PostgreSQL tests cover successful key enrolment/login proof, public-key
persistence and audit events, PENDING_OTP-only transition, protected endpoint
rejection, wrong signatures, changed signed bytes, expired/replaced challenges,
replay after enrolment and login, unknown/cross-user keys, cross-attempt proof,
wrong purpose/stage, expired/revoked pending attempts, password-only replacement
rejection, concurrent enrolment/login challenge consumption, revoked credentials,
unsupported curves, rejected client boolean flags and per-attempt rate limits.
A datastore-outage test verifies safe 503 handling rather than disguising an outage
as an invalid signature/context. Failed proof auditing runs outside the rollback.

The server tests deliberately use exportable software test-fixture keys to isolate
ECDSA protocol/state behavior. They do not exercise Android Keystore. The separate
native tests above provide OS/API evidence, with the stated hardware limitations.

## Flutter coverage

The final 62-test suite retains the Phase 3 forms/network/route/layout checks and
adds server-confirmed enrolment and pending-OTP transitions, cancellation, no
biometrics, unavailable hardware, temporary/permanent lockout, invalidated/missing
keys, authentication failure, expired challenge, network interruption, duplicate
operation/loading behavior and native-channel capability/error mapping. These
fixtures are confined to tests. Actual native lockout, enrolment-change invalidation
and physical device/vendor behavior were not claimed as tested.

## Build, launch and service readiness

The normal entrypoint was rebuilt after integration tests:

```sh
flutter build apk --debug
flutter run -d emulator-5554 --debug --no-resident --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk
```

Both commands exited 0. Installation reported 2,566 ms. adb confirmed
com.example.authvault/.MainActivity as the top resumed activity and process 10582
running. The normal welcome screen was visually inspected in the
[launch capture](images/phase-4/normal-app-launch.png). The app was left running.
The final backend was rebuilt/restarted with BiometricModule and its readiness
endpoint was checked against the real database.

An initial regression test expected the old four-field password response; it was
updated for the necessary subjectId field. Test-style lint issues were fixed before
final analysis. A final review tightened native stale-callback/prompt-exception
handling; both native integrations passed again afterward. A backend error-mapping
correction gained a regression test before the final passing backend run.

Java native-access, Android debug startup/skipped-frame/input warnings appeared.
One early native test logged Android's diagnostic signal during slow startup but
completed successfully. These are not performance or hardware-security results.
Earlier phase validation files remain historical records rather than new claims.

## Remaining validation and phase gate

Required physical-device checks: real TEE/StrongBox and attestation properties,
strong face/fingerprint devices, supported OS/vendor versions, prompt lockout,
biometric addition/removal invalidating existing keys, screen-lock removal, reboot
persistence, device migration/recovery and release-build policy. iOS signing,
recovery, OTP, completed sessions and production attestation remain unimplemented.

Suggested commit: `feat: add biometric-protected Android keys and signed MFA challenges`

Phase 5 has not started and requires explicit approval.
