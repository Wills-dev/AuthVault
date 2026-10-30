# Phase 5 validation — 30 October 2026

These results were executed locally. Earlier phase records are historical. No
Phase 6 implementation or production deployment was performed.

## Environment and commands

Flutter 3.47.9 / Dart 3.13.7; Node 24.22.1; NestJS 12.3.2; Prisma 7.10.1;
local PostgreSQL 17.10 on loopback 55432. Integration tests migrate only
`authvault_test`; application migration uses local `authvault`. Android target:
`emulator-5554`, API 37 arm64, fingerprint 1 enrolled in OS settings.

| Executed check | Actual result |
| --- | --- |
| `dart format .` | Passed |
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed: 78 tests |
| Backend `npm run format:check` | Passed |
| Backend `npm run lint` | Passed |
| Backend `npm run build` | Passed |
| Backend `npm test` | Passed: 8 unit + 37 integration = 45 tests |
| Backend `npm run smoke` | Passed against the running local server |
| `npm audit --omit=dev` | Passed: 0 known runtime vulnerabilities reported |
| `npm run generate` | Passed |
| `npm run db:migrate` | Applied additive Phase 5 migration locally |
| `npx prisma validate` | Passed |
| `npx prisma migrate status` | Up to date; all 3 migrations applied |
| `npx prisma migrate diff --from-config-datasource --to-schema prisma/schema.prisma --exit-code` | Passed, no difference |
| `flutter build apk --debug` | Passed |
| Full native MFA emulator integration | Passed; actual SMTP mailbox code, no hardcoded accepted code |
| Normal-entrypoint emulator launch | Passed with emulator-only Skia software-rendering flags; welcome screen visually verified |

Backend integration exercised real PostgreSQL locks and actual SMTP exchanges
using an ephemeral loopback smtp-server receiver. Cases include valid/invalid,
expired/reused/cross-attempt codes, revoked credential binding, cooldown/replacement,
five-failure exhaustion/user lockout, request limits, accepted-send cap, concurrent
verification, SMTP rejection and failed replacement preserving the previous code.
It checks pending-Bearer rejection, actual JWT account authorization, required
factors/issuer/audience/algorithm/expiry checks, refresh rotation/replay/concurrency,
logout/live JWT revocation and expired sessions. Test software EC keys are explicitly
fixtures, not evidence of Android hardware enforcement.

Flutter tests cover OTP formatting/paste/validation, countdown boundaries, resend
states, errors/network failure and localized loading, successful session persistence,
restoration rotation, failed/invalid restoration, storage failure, local logout on
network failure, serialized refresh, logout during refresh, session expiry and
protected redirects. Dashboard/profile additionally fit 320×568 and 568×320 logical
pixels at 2× text scaling. The original credential, biometric and debug-preview
regression checks remain included. No overflow exception was reported by these tests.

## Actual Android flow

```sh
flutter drive --driver=test_driver/full_mfa_driver.dart --target=integration_test/full_mfa_test.dart -d emulator-5554
```

The scenario registers random fixture credentials, enrols an Android Keystore key
through a real biometric prompt, logs in, signs/verifies a LOGIN challenge, reaches
PENDING_OTP and confirms dashboard denial at that stage. It requests a real email
through Nodemailer to the bundled controlled SMTP mailbox. After SMTP acceptance,
test-only code reads its recipient's message, submits a deliberately different code
and confirms rejection, pastes the actual delivered code, completes MFA and loads
the real protected identity/security endpoints. No success API response is mocked.

It then discards all Dart providers (including the access JWT), creates a fresh
provider container and restores using the actual Android secure-storage refresh
credential plus backend rotation. It opens profile, logs out and confirms protected
navigation is denied again. This establishes secure-storage/provider restart behavior;
it does **not** claim an OS process-kill/reboot restoration experiment. Native emulator
finger events are supplied by host test tooling; the app/backend proof checks remain
real. Hardware-backed protection was reported **false** by this emulator; no physical
hardware assurance or biometric accuracy result is claimed.

Two initial device runs exposed a test-input replacement issue: a second synthetic
text-entry call left the prior value in the field. A redacted boolean assertion
confirmed the mismatch without logging values. The final test uses Android clipboard
paste with full selection and clears its test clipboard afterward. The pasted value
is asserted to match the mailbox before real HTTP verification. Initial failures are
not counted as passes. A separate screenshot capture issue was traced to replacing
report metadata; the harness now preserves screenshot metadata and excludes image
bytes from its non-secret JSON evidence.

## Measured timings and limits

One completed backend run measured 1.462 seconds for 8 unit tests and 19.979 seconds
for 37 integration tests. A completed native E2E scenario reported 19 seconds
(excluding build/install). These are local test-run durations, not production latency.
Five sequential local `/v1/health/ready` requests returned 200 with measured elapsed
values **32.07, 2.57, 2.60, 1.16 and 2.00 ms**. No password, OTP, refresh or remote
provider latency benchmark is claimed.

SMTP acceptance and message receipt were verified on the controlled local mailbox.
The dependency audit reported zero known runtime advisories at execution time;
this is a snapshot, not a security guarantee. External inbox delivery, provider reputation/DNS, production TLS SMTP credentials,
production load, physical-device security and iOS were not validated. Mailpit is an
optional documented alternative; Docker/Mailpit was not run on this host.

Code lifetime is capped at five minutes and at the pending-attempt deadline. SMTP
acceptance and PostgreSQL commit are not a distributed transaction; a commit failure
can leave an unusable email. Lost OTP-completion/refresh responses can require fresh
login. Logout is stateful: protected guards consult the live database session, so
subsequent JWT use is rejected; already-authorized in-flight requests can complete.
Offline logout clears local access but cannot claim server revocation confirmation.
See [implementation/security limits](phase-5-implementation.md).

## Visual evidence and normal app launch

Captured and visually inspected [OTP issued](images/phase-5/otp-issued.png),
[real dashboard](images/phase-5/dashboard.png) and [real profile](images/phase-5/profile.png).
OTP capture precedes code entry; no OTP or credential is in these committed images.
The long generated fixture email wraps within its card. No overflow was observed.
The dashboard/profile render actual fixture identity, active credential/session counts
and a backend completion timestamp. Native evidence is recorded without credentials
in [phase-5-native-evidence.json](phase-5-native-evidence.json).

The final screenshot-enabled E2E run completed successfully in 20 seconds excluding
build/install. It used the default renderer. The normal-entrypoint APK then built in
13.8 seconds. The emulator process stopped before the subsequent normal launch.
The same AVD was restarted without wiping data. Android initially kept credential
storage locked; verifying the existing private emulator PIN unlocked it. No PIN was
changed. After reboot, Android displayed a **System UI isn't responding** dialog and
showed unreliable display updates. Restarting the stalled System UI service and
AuthVault restored activity startup (`am start -W`: Status ok, then HOT launch with
1,337 ms wait); window inspection confirmed AuthVault focus. Default-renderer cold
launch was not reliably visually confirmed during this guest failure.

The final **normal application** launch succeeded and its welcome screen was captured
and visually inspected with the following emulator-only runtime workaround:

```sh
flutter run --debug --no-enable-impeller --enable-software-rendering --no-resident -d emulator-5554 --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk
```

[Normal app launch](images/phase-5/normal-app-launch.png). The command exited 0 and
synced files successfully. No Android/Gradle configuration or native biometric code
was changed. Software rendering alone was initially rejected by Impeller; adding
`--no-enable-impeller` was required. Those failed diagnostic launches are not counted
as passes. Flutter warns that opting out of Impeller is deprecated; this is a local
emulator diagnostic, not a production rendering policy. The full real-MFA test and
its OTP/dashboard/profile captures had already passed with the default renderer
before this reboot. Post-reboot API 37 emulator instability remains an environment
limitation, not a claimed application/security fix.

The emulator's clock can differ slightly from the server, so client countdown
presentation is approximate; server deadlines and cooldown checks remain authoritative.
