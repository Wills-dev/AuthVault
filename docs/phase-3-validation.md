# Phase 3 validation — 30 October 2026

## Environment and provisioning

Inspected Node 24.22.1, npm 11.19.1, Flutter stable 3.47.9 and Dart 3.13.7.
PostgreSQL and Docker were initially absent from PATH. Homebrew's PostgreSQL 17
installation stalled downloading a source dependency on this macOS 14 host and
was stopped; it was not reported as a successful installation. An official
Postgres.app download was also stopped after a working fallback became available.

A development-only prebuilt binary package was installed under ignored
backend/.local/pg-tools: @embedded-postgres/darwin-arm64@17.10.0-beta.17.
Its wrapper is beta; the executed postgres binary reported PostgreSQL 17.10.
The package's local library symlinks were restored using its reviewed hydration
script. This is third-party local tooling, not a backend runtime dependency.
Exact alternative installation commands are in backend/README.md.

The dedicated cluster started successfully on 127.0.0.1:55432 with SCRAM
authentication, generated secrets, separate application/admin roles and application
and test databases. The app role is a non-superuser. No system PostgreSQL service
was enabled. Docker remains unavailable but is no longer a validation blocker.
Secrets, cluster files and generated Prisma source are ignored by Git.

## Executed results

| Check | Actual result |
| --- | --- |
| Prisma client generation | Passed, Prisma 7.10.1 client generated |
| Prisma schema validation | Passed |
| Application migration | Passed, initial SQL migration applied to authvault |
| Test migration | Passed, applied to isolated authvault_test; subsequent deploy reported no pending migration |
| Backend startup | Passed; NestJS started and connected to PostgreSQL |
| Readiness | Passed, GET /v1/health/ready returned 200 and database reachable |
| Backend formatting | Passed, Prettier check and Prisma formatting |
| Backend lint | Passed, ESLint |
| Backend compilation | Passed, strict tsc; test-source no-emit type check also passed |
| Backend tests | Passed, 8 unit + 10 real HTTP/PostgreSQL integration tests |
| Running-server smoke | Passed, separate real HTTP registration/login/status/protected-resource/revocation checks |
| Flutter formatting | Passed, 31 Dart files, no changes on final check |
| Flutter analysis | Passed, no issues found |
| Flutter tests | Passed, 49 tests |
| Android real authentication integration | Passed, one on-device test plus teardown; real backend via 10.0.2.2 |
| Existing screen-gallery integration | Passed, one on-device test plus teardown |
| Normal Android debug APK | Passed, flutter build apk --debug exited 0; assembleDebug 13.7 s |
| Normal emulator launch | Confirmed by foreground activity, running process and visually inspected rendered welcome screen after emulator recovery |
| iOS/release/real biometric cryptography | Not run/not implemented in this phase |

No mocked HTTP adapter is counted as real backend validation. Real PostgreSQL
integration tests exercise Nest's HTTP stack, database constraints and transactions,
Argon2id and shared counters. Separate smoke checks use the independently running
backend, random temporary credentials and cleanup of the smoke account.

## Security-relevant checks

Backend tests verify successful registration, normalized uniqueness/duplicate
handling, weak/invalid/extra/oversized/malformed input rejection, salted Argon2id
hashing and correct/incorrect/unknown-user password verification. Stored attempt
material is checked against a hash of the response secret. Login returns only
PENDING_BIOMETRIC, never accessToken or refreshToken; authenticated-session and
refresh tables remain empty in those tests.

Pending status rejects missing/wrong secrets, revocation and expiry. Protected
/v1/users/me and /v1/users/me/security return 403 even with pending credentials
presented as Bearer tokens. Per-account and per-IP rate limits return 429 with
Retry-After. Simulated database exceptions produce safe 503 responses; actual
PostgreSQL connectivity and transactions are separately tested. Audit records are
checked for expected events and absence of the fixture password/pending secret.

Flutter tests cover request bodies and normalization, pending-token header usage,
API error mapping, network failures, request cancellation, malformed response
rejection, pending state transitions/expiry, local-versus-production URL policy,
loading/duplicate prevention, forms, OTP UI and route guards. Adapter fixtures are
clearly test-only; no successful API behavior is fabricated in the shipping app.
The existing 14-case large-text/small-screen/keyboard layout matrix still passes.

## On-device and running-server validation

Executed with the real local backend:

```sh
cd backend
npm run generate
npm run db:migrate
npm run build
npm test
npm start
# In another terminal, from backend/:
npm run smoke
```

Smoke assertions passed: readiness 200, registration 201, password login 200 with
pending MFA only, pending status 200, protected resource 403, wrong password 401,
and pending-attempt revocation 204. No secrets are printed by the smoke script.

From the repository root:

```sh
flutter test
flutter analyze
flutter drive --driver=test_driver/password_auth_driver.dart --target=integration_test/password_auth_test.dart -d emulator-5554
flutter drive --driver=test_driver/ui_gallery_driver.dart --target=integration_test/ui_gallery_test.dart -d emulator-5554
```

The real authentication test registered through the Flutter form, confirmed server
pending enrolment, submitted password login, confirmed pending biometrics, checked
that /dashboard still redirects to login, and revoked its pending attempt.
It used random fixture credentials and no HTTP/platform authentication mocks.
The final successful test body reported approximately 86 seconds on the slow debug
emulator. The gallery regression reported approximately 54 seconds. These figures
are tooling observations, not production latency or authentication-success metrics.

An earlier authentication integration attempt was interrupted after stalling in
optional screenshot surface conversion and showing an Android not-responding dialog.
It is not counted as passing. Optional capture was removed from the authentication
test, and the full corrected flow then completed successfully. The independent
existing gallery capture regression also completed successfully. A Dart test-fixture
syntax error, test-owned pending-timer cleanup and parser error-code expectation
were corrected before the final passing runs.

## Normal APK launch and emulator recovery

The normal-entrypoint `flutter build apk --debug` succeeded and produced
build/app/outputs/flutter-apk/app-debug.apk. Subsequent `flutter run` attempts
failed during streamed installation with an adb broken pipe. A non-streaming
attempt initially found Android's package service missing. Emulator /data had
8.4 GiB available, so this was not a full-disk failure. A guest reboot and ordinary
cold start did not provide a stable installer.

The same AVD was finally cold-started without wiping data or editing saved AVD
configuration, using these runtime options:

```sh
/Users/a0000/Library/Android/sdk/emulator/emulator -avd Medium_Phone_API_37.0 -port 5554 -no-snapshot-load -no-snapshot-save -no-boot-anim -memory 2048 -cores 2 -gpu swiftshader -feature -Vulkan -no-audio
```

The emulator enforced 4096 MiB RAM despite the requested 2048 MiB; no claim is
made that RAM was actually reduced. Boot completion and package-service presence
were checked before a bounded non-streaming install. That install returned
**Success** (APK push 5.149 s). The activity command accepted the request but
reported `Status: timeout`, so its exit code alone was not counted as launch proof.

```sh
adb -s emulator-5554 install --no-streaming -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am start -W -n com.example.authvault/.MainActivity
```

Afterward, dumpsys reported com.example.authvault/.MainActivity as the top resumed
activity, pidof returned process 3096, and an adb screenshot was visually inspected:
the normal welcome screen rendered correctly. See the
[final normal-app capture](images/phase-3/normal-app-launch.png). The app was left
running on emulator-5554. This successful observation does not retroactively mark
any failed Flutter launch command as passed. No Gradle or app-source workaround
was introduced for the emulator's service instability.

## Dependency and deployment limits

npm audit --omit=dev reported zero known vulnerabilities at the executed snapshot.
The full audit reported six low-severity development-tool findings in deepmerge
and its Jest/ts-jest dependents. No forced breaking dependency upgrade was applied.
This snapshot does not prove dependency or application security.

Emulator logs included Java native-access, Android rendering/input and skipped-frame
warnings. Do not infer performance or physical biometric security from these runs.
Full Xcode/CocoaPods remain missing, so no iOS build was claimed. No release binary,
real biometric key proof, email OTP, completed session, refresh rotation or production
TLS deployment was evaluated. See phase-3-implementation.md for security assumptions,
registration enumeration limits and retention/proxy/capacity limitations.

## Phase gate

Suggested commit: `feat: add NestJS password authentication and pending MFA integration`

Phase 4 has not started and requires explicit approval.
