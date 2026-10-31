# Reproducible academic demonstration

This runbook describes expected behavior and how to rehearse it. **It does not claim a new Phase 7 execution.** The last successful full native run is the [Phase 6 record](../phase-6-validation.md), with [native JSON](../evidence/phase-6/native-evidence.json) and dated screenshots. Use a dedicated local demonstration environment and owned fixture accounts. Do not deploy the prototype or substitute production services.

## Prerequisites and safety boundary

- Project dependencies/lockfiles; Flutter 3.47.9/Dart 3.13.7 and Node 24.22.1/npm 11.19.1 match recorded validation.
- PostgreSQL 17 binaries and the project's dedicated local cluster, or an already configured owned local development database. Do not replace an unrelated `.env` or database.
- Android Platform 36, Build Tools 36.0.0, NDK 28.2.13676358, Android Studio/JDK and an existing API 37 AVD. `emulator-5554` must be fully booted and manually unlocked.
- A strong fingerprint enrolled in Android Settings, with its virtual sensor identity known to the operator. The screen-lock PIN stays private. Do not wipe the AVD, change/guess its PIN or guess enrolled fingerprint IDs.
- Three terminals: backend setup/server, loopback mailbox, Flutter. Keep one instance of each service; do not start a second cluster on occupied port 55432.
- Use a new owned fixture address such as `defense-<unique-suffix>@example.test`, a fictitious full name and a unique randomly generated password of at least 12 characters, at most 128. Store it privately for the demo. The bundled mailbox accepts this test domain; it is not external email delivery.
- Show only the intended app window. Keep `.env`, passwords, native PIN, OTP messages, tokens and logs with sensitive contents off the projector/recording. Never send a PIN to an assistant or include secrets in a command line.

The normal manual demonstration below does not run screenshot/aggregate scripts. Preserve all existing `docs/evidence/phase-6` and `docs/images/phase-6` files. The optional native harness must run in an isolated source copy because it writes Phase 6-named capture paths.

## 1. Prepare dependencies and database

From the repository root:

```sh
flutter --version
flutter pub get
cd backend
node --version
npm ci
npm run db:local
node scripts/configure-local-auth.mjs
npm run generate
npm run db:migrate
npm run build
```

**Expected:** dependency resolution succeeds, the dedicated loopback PostgreSQL cluster starts, the local `authvault` and `authvault_test` databases are available, existing migrations apply and TypeScript compiles. `db:local` generates ignored credentials only if `.env` is absent. `configure-local-auth.mjs` appends missing development settings without replacing existing secrets. Never print `.env` as a diagnostic.

`db:local` expects `/opt/homebrew/opt/postgresql@17/bin` by default. If this host's previously provisioned embedded binary is present, the recorded alternative from `backend/` is:

```sh
POSTGRES_BIN="$PWD/.local/pg-tools/node_modules/@embedded-postgres/darwin-arm64/native/bin" npm run db:local
```

This is a host-specific existing binary path, not an instruction to assume that package exists on another machine. Otherwise install PostgreSQL 17 through your approved local setup and set `POSTGRES_BIN` to its binary directory. The script refuses unrelated database URLs; honor that refusal rather than changing credentials to force it. See the [backend setup](../../backend/README.md) for the historical provisioning details.

## 2. Start the private mailbox and backend

In terminal B, from `backend/`:

```sh
node scripts/mailbox.mjs
```

**Expected:** loopback SMTP on `127.0.0.1:1025`, private message JSON at `http://127.0.0.1:8025/messages`. Message bodies are not logged. The mailbox retains at most 50 messages in memory and exposes messages received in the last ten minutes. Stop it after the demonstration. It has no public authentication and must remain loopback-only.

In terminal A, from `backend/`:

```sh
npm start
```

In another terminal, check database readiness without credentials:

```sh
curl --fail http://127.0.0.1:3000/v1/health/ready
```

**Expected:** HTTP 200 with healthy status and database reachable. A live port alone does not establish database readiness. Configuration uses local HTTP only for development; do not weaken release HTTPS validation. Mailpit is an optional separate tool, but its API is not the bundled `/messages` contract required by the canonical E2E harness.

## 3. Start and verify the emulator

Open Android Studio Device Manager and start the existing API 37 AVD. Wait for full boot, unlock it manually and verify enrolled fingerprints in Android Settings. From the repository root:

```sh
flutter devices
"$HOME/Library/Android/sdk/platform-tools/adb" devices
"$HOME/Library/Android/sdk/platform-tools/adb" -s emulator-5554 shell getprop sys.boot_completed
```

**Expected:** target `emulator-5554`, device state `device`, boot property `1`, and a visibly unlocked home screen. The quoted SDK path is this macOS host's location; use your SDK's `adb` elsewhere. Device enumeration does not by itself prove unlock or sensor readiness. Arrange for the user/operator to press **Touch sensor** for the enrolled virtual fingerprint whenever each native prompt is visible. Phase 6 rejected automatic IDs 1 and 2, so do not assume either is enrolled now.

## 4. Build and launch the normal app

From the repository root, with backend/mailbox running:

```sh
flutter run --debug -d emulator-5554
```

Debug defaults to `http://10.0.2.2:3000/v1`, the Android emulator alias for the host. It is not `127.0.0.1` inside the guest. This API 37 emulator previously required the following rendering workaround:

```sh
flutter run --debug -d emulator-5554 --no-enable-impeller --enable-software-rendering
```

Use the second command if the known rendering issue recurs; run one Flutter tool at a time. These flags are an emulator diagnostic, not a release configuration change. **Expected:** real Welcome/Login UI, with no authenticated session for a fresh account. An old saved session may show a restoration gate or its owned account; sign out before starting a new fixture. Do not use the debug preview as authenticated demonstration evidence.

## 5. Register and enrol biometrics

1. Choose registration. Enter the fictitious full name, unique fixture email, private random password and matching confirmation. Optionally demonstrate an invalid email/mismatched confirmation before submitting valid data.
2. Press **Create account**. Expect pending enrolment/device readiness, not the dashboard.
3. Press **Enrol device biometrics**. When Android's native prompt opens, the operator supplies the enrolled virtual fingerprint through emulator controls. This is the **first native prompt**.
4. Expect enrolment completion and **Return to login**. Select it. No access/refresh credentials should have been issued merely for registration/enrolment.

If the prompt is cancelled or the print rejected, show the actual failure and retry only with the correct enrolled input. Do not replace a failure with a fake successful callback. Missing/revoked keys have no implemented recovery flow; use a fresh owned fixture account rather than overwriting another account's credential.

## 6. Password login and biometric proof

1. Enter the same fixture email/password and press **Continue securely**.
2. Expect pending biometric verification. A correct password alone must not show protected account data.
3. Press **Verify with biometrics**. Supply the enrolled virtual fingerprint at the **second native prompt**.
4. Expect the OTP screen after server signature verification. If needed, choose **Continue to email verification** when shown. No session has yet been granted.

The server challenge lifetime is at most 120 seconds, capped by the pending attempt. Do not pause indefinitely at a prompt. If the attempt expires, start a new sign-in; do not modify server TTLs or bypass the proof.

## 7. Deliver and verify the email code

1. Press **Send email code** if no challenge is issued yet. Expect a resend countdown and delivery metadata, not a displayed accepted OTP.
2. Privately open `http://127.0.0.1:8025/messages` on the host. Select the newest message addressed to the exact fixture email. The JSON contains raw message text; read its actual six-digit code without projecting the mailbox-wide list.
3. Enter/paste the delivered code and press **Verify email code**. Preserve leading zeroes. For an optional negative demonstration, use one code confirmed different from the delivered one, show rejection, then submit the actual code. Do not exhaust the account or use a hardcoded “valid” value.
4. Expect session issuance and protected account retrieval only after verification and secure persistence succeed.

Default code validity is at most five minutes and never exceeds the pending attempt; resend defaults to 60 seconds and invalidates the prior code after accepted replacement. Use the newest message. SMTP acceptance is not proof of real external provider delivery; local mailbox receipt is the demonstrated boundary.

## 8. Dashboard and profile

Show the actual fixture identity, security cards/counts and latest authentication state on the dashboard. Navigate to profile/security and back. Explain that these values come from `/users/me` and `/users/me/security`, not a preview's sample activity. The historical UI says “three authentication factors completed”; explain this as three workflow checkpoints, not a proven independence/assurance claim. Do not call an authentication activity card a complete device/IP history or claim unimplemented settings are operational.

## 9. Session restoration

The executed Phase 6 restoration recreated a provider container with real secure storage and server-side refresh rotation. The optional harness below reproduces that validated scope.

For a **separate manual process-restart rehearsal**, while signed in and with services running, detach the Flutter runner without stopping the app (Flutter terminal `d`), then:

```sh
"$HOME/Library/Android/sdk/platform-tools/adb" -s emulator-5554 shell am force-stop com.example.authvault
"$HOME/Library/Android/sdk/platform-tools/adb" -s emulator-5554 shell am start -n com.example.authvault/.MainActivity
```

**Expected design behavior:** startup reads the saved refresh credential, rotates through the backend and grants access only after success. Network/storage errors should show the restoration gate with retry/signout. **This OS process-restart experiment was not part of the recorded Phase 6 pass**; rehearse it and record the actual outcome separately before claiming it in a defense. If it fails, disclose that result and demonstrate the already evidenced provider-container restoration instead. Do not label an expected outcome as an executed pass.

## 10. Logout and denial of unauthorized access

Use the real logout action on dashboard/profile. Expect immediate signed-out UI and independent secure-storage cleanup/server revocation attempts. Report any feedback about incomplete cleanup honestly. Do not reopen a preview and describe it as a remaining authenticated session.

Check unauthenticated API access safely without printing tokens:

```sh
curl --silent --output /dev/null --write-out '%{http_code}\n' http://127.0.0.1:3000/v1/users/me
```

**Expected:** `401`. This demonstrates missing-credential denial. Revoked-JWT reuse and signed-out direct protected-route rejection are separately covered by the recorded automated regressions/canonical harness. The app has no configured general-purpose Android URL deep-link demo; do not invent an `adb` URL command to claim one. Route guards and server authorization are separate checks.

## Optional canonical native retest

Use this for automated assertions of the full native flow, including provider-container restoration, wrong-code rejection and protected-route denial. It needs the same running owned local backend and bundled mailbox. **It writes capture files**, so create an isolated copy from the approved committed source rather than using the submission checkout:

```sh
AUTHVAULT_DEMO_DIR="$(mktemp -d /private/tmp/authvault-demo.XXXXXX)"
git archive HEAD | tar -x -C "$AUTHVAULT_DEMO_DIR"
cd "$AUTHVAULT_DEMO_DIR"
flutter pub get
AUTHVAULT_TEST_FINGERPRINT_ID=manual flutter drive --dart-define=MANUAL_BIOMETRIC_TEST=true --no-enable-impeller --enable-software-rendering --driver=test_driver/phase_6_mfa_driver.dart --target=integration_test/full_mfa_test.dart -d emulator-5554
```

Run the archive command from the submission repository root. It uses **committed** source, so ensure that commit is the intended approved application revision. Do not copy `.env` or private files into a handout/archive. Keep the existing local backend/mailbox running; do not bootstrap a competing cluster in the copy. The test creates its own random account/password and reads the actual delivered mailbox code; no credentials need to be entered into terminal arguments.

Supply the enrolled fingerprint twice when the native prompts are visible. Manual mode allows a 110-second transition wait without increasing the server's challenge lifetime. Do not omit `AUTHVAULT_TEST_FINGERPRINT_ID=manual` unless you explicitly know the enrolled virtual ID; the driver's default ID is 1, which was rejected during Phase 6. An automatic known ID must be between 1 and 10. No driver substitutes for cryptographic verification.

**Expected if successful:** test reports a pass, actual account data, logout denial and captures in the isolated copy's `docs/images/phase-6/`; native response data is in that copy's ignored `backend/.local/phase-6-native-evidence.json`. This is a new run, not permission to overwrite submitted historical evidence. Preserve its command, date, environment and any failures separately. Capture files alone do not establish assertion success.

After any integration entrypoint, rebuild and launch the normal app **sequentially**, from the intended checkout:

```sh
flutter build apk --debug --target lib/main.dart
flutter run --debug -d emulator-5554 --no-enable-impeller --enable-software-rendering --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk
```

If a stale generated `integration_test` plugin registration prevents the build, stop concurrent Flutter tools, run `flutter clean`, `flutter pub get`, then rebuild sequentially. Do not hand-edit generated Java or add a test plugin as a production dependency.

## Troubleshooting and fallback

| Symptom | Check/action | Do not claim |
| --- | --- | --- |
| Readiness fails | Verify local PG binary/cluster, configured development DB and applied migrations; inspect safe errors without printing secrets | That liveness proves database readiness |
| Port already occupied | Identify your existing local service and reuse the intended instance; do not kill unknown processes | That two copies can own the same ports |
| Connection failure on emulator | Check host readiness and debug API alias `10.0.2.2:3000/v1` | That emulator loopback is the host or TLS should be disabled in release |
| Emulator locked/not booted | Wait for full boot; user unlocks privately | That PIN guessing/reset is an authentication workaround |
| Fingerprint rejected | Use the actual enrolled sensor input; cancel safely and respect lockout | That default ID 1/2 must match |
| Rendering failure | Try the documented emulator Skia flags | That native MFA passed merely because the screen renders |
| No OTP message | Check exact recipient, bundled mailbox, SMTP settings and send response; respect cooldown | That `SMTP_ACCEPTED` guarantees external inbox delivery |
| Invalid/expired code | Use newest actual code, check server deadline, start new sign-in if pending attempt expired | That a hardcoded test code is legitimate |
| Restore fails | Show gate; retry with services restored or sign out; strict refresh replay may require fresh login | That OS-restart restoration was previously measured |
| Live demo cannot complete | Show dated Phase 6 evidence and explicitly identify the current failed step | That screenshots or debug previews are a live authenticated pass |

Stop the local backend and mailbox with Ctrl-C in their own terminals after the session. Leave existing AVD PINs/enrolments intact. Retain only sanitized demonstration notes/screenshots, never private `.env`, tokens, password/PIN material or raw OTP messages. Fixture retention is manual at present; there is no implemented automated account-cleanup lifecycle to promise.
