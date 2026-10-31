# Testing and evaluation

This is an academic synthesis of **executed Phase 6 evidence dated 30 October 2026**, not a new Phase 7 test run. Historical passes, failed attempts, expected security rejections and unmeasured properties are kept distinct. Primary records: [validation](../phase-6-validation.md), [coverage](../test-coverage.md), [performance methodology](../performance-evaluation.md), [audit](../phase-6-security-audit.md).

## 1. Environment and method

Flutter 3.47.9/Dart 3.13.7; Node 24.22.1/NestJS 12.3.2/Prisma 7.10.1; local PostgreSQL 17.10; Android Platform 36/Build Tools 36.0.0/NDK 28.2.13676358; API 37 arm64 `emulator-5554`. Backend integration uses isolated `authvault_test`, real HTTP through Supertest, real database transactions and controlled SMTP. Native tests use actual Android prompts and Keystore signing. Software EC fixtures in backend tests are deliberately separate from native evidence.

Flutter tests replace dependencies where appropriate to exercise UI/state deterministically; they do not all make real network or biometric calls. Backend unit tests isolate individual behavior; integration tests exercise persistence and protocol transitions. The final native flow combines the actual app, API, database and local mailbox, with the user supplying the enrolled virtual fingerprint.

## 2. Results and traceability

| Category | Executed outcome | Evidence/source |
| --- | --- | --- |
| Flutter unit/widget suite | **87 passed** | [Phase 6 executed checks](../phase-6-validation.md); [tests](../../test) |
| Backend unit tests | **21 passed** | [Backend test sources](../../backend/test); included in 69 total |
| Backend integration tests | **48 passed** | Same six-suite run, isolated PostgreSQL/SMTP |
| Backend total | **69 passed in six suites** | `npm run test:coverage` recorded in validation |
| Formatting/static analysis | Dart format and Flutter analyze passed; backend lint/build/format check passed | Phase 6 validation; no new application check claimed in Phase 7 |
| Schema | Valid; three migrations applied; no drift | Phase 6 validation; no Phase 6 schema migration |
| Actual native cancellation | Passed; scenario **4 s** | [Cancellation test](../../integration_test/native_biometric_cancel_test.dart) |
| Actual complete native MFA | Passed; scenario **29 s** | [Native evidence JSON](../evidence/phase-6/native-evidence.json) |
| Normal debug app | Build **11.9 s**, launch exit **0**, focused MainActivity, signed-out login inspected | Native JSON and normal launch screenshot |
| Responsive/accessibility | No overflow in passing checked layouts; four automated accessibility checks | [Accessibility tests](../../test/accessibility_test.dart), validation |

The 87 count is the Flutter suite, not 87 native end-to-end executions. The native scenarios and historical Phase 1–5 runs are not added to it to inflate a single total.

## 3. Coverage

Source: [coverage-summary.json](../evidence/phase-6/coverage-summary.json). Percentages below retain the recorded two-decimal rounding.

| Metric | Covered / reported total | Percentage |
| --- | --- | --- |
| Backend lines | 1,647 / 1,656 | **99.45%** |
| Backend branches | 371 / 443 | **83.74%** |
| Backend functions | 111 / 111 | 100.00% |
| Flutter lines | 753 / 980 | **76.84%** |
| Flutter branches | Not collected | Not reported |
| Kotlin/native lines/branches | Not instrumented | Not reported |

### Backend modules

| Module | Lines | Line coverage | Branches | Branch coverage |
| --- | --- | --- | --- | --- |
| Bootstrap/configure | 47/47 | 100.00% | 2/2 | 100.00% |
| Auth | 388/388 | 100.00% | 71/87 | 81.61% |
| Biometric | 407/409 | 99.51% | 93/112 | 83.04% |
| Common | 74/76 | 97.37% | 19/26 | 73.08% |
| Config | 57/59 | 96.61% | 41/46 | 89.13% |
| Health | 15/15 | 100.00% | 4/5 | 80.00% |
| OTP | 339/342 | 99.12% | 75/88 | 85.23% |
| Prisma | 31/31 | 100.00% | 3/4 | 75.00% |
| Session | 222/222 | 100.00% | 56/63 | 88.89% |
| Users | 67/67 | 100.00% | 7/10 | 70.00% |

### Flutter modules

| Library group | Covered / reported lines | Coverage |
| --- | --- | --- |
| App | 70/81 | 86.42% |
| Core | 100/132 | 75.76% |
| Authentication | 536/703 | 76.24% |
| Dashboard | 41/58 | 70.69% |
| Profile | 6/6 | 100.00% |

Backend V8/ts-jest coverage includes structural/decorator lines; generated Prisma and `src/main.ts` are excluded. Flutter reports only libraries in LCOV; `lib/main.dart`, design tokens and the auth repository interface were unreported. The denominator is not every repository line. Neither high line coverage nor a module with 100% of six lines establishes exhaustive behavior or security coverage.

## 4. Security and state regression matrix

| Area | Cases exercised | Supported conclusion and limit |
| --- | --- | --- |
| Password boundary | Wrong/unknown credentials, manipulated stage/client fields, pending credential used as Bearer | Executed cases could not create protected access; signup enumeration separately confirmed |
| Biometric proof | Alteration, wrong key, expiry, replay, user/attempt mismatch, concurrent submissions | Context and single-use checks worked in exercised cases; no key attestation |
| OTP | Wrong/expired/reused/cross-attempt codes, cooldown, replacement, exhaustion, quotas, concurrent use | Server, not client countdown, enforces the lifecycle |
| SMTP | Rejection, accepted replacement and local mailbox receipt | Local behavior tested; not external inbox deliverability |
| JWT/account | Unsigned/wrong-key JWT, subject/session mismatch, cross-account selectors, credential revocation | Signature plus live authorization enforced for tested protected routes |
| Refresh | Rotation, consumed-token replay, concurrent family revocation, expiry | Replay closes the family; legitimate concurrent retry can require login |
| Logout/restoration | Delete failure, initial-read race, stale refresh/cleanup, serialized storage, persistence failure, network retry | Remediated race regressions passed; joint cleanup/network failure remains uncertain |
| HTTP/release | Spoofed forwarded IP, safe errors/security headers/CORS, manifest/signing review | Configured boundaries observed; not deployed TLS or independent pentest |

See [Phase 6 audit](../phase-6-security-audit.md) for finding severity and exact remediation status. The review found no Critical unauthorized-account MFA bypass within the executed scope. It did confirm a **High remote biometric-assurance gap**: an enrolled exportable software key can satisfy the server with the other required credentials. The two statements are compatible and must be presented together.

## 5. Native end-to-end evidence and unsuccessful attempts

The successful run registered owned random fixture credentials, authorized enrolment and login signatures through native prompts, reached `PENDING_OTP`, obtained a real local SMTP message, rejected a deliberately wrong code, accepted the delivered code, retrieved real dashboard/profile data, recreated the provider container to rotate secure-storage credentials, logged out and confirmed protected-route denial.

The **29-second** scenario excludes a **20.8-second build** and **3.5-second install**. Sensor input was manually supplied by the user. The renderer flags were `--no-enable-impeller --enable-software-rendering`; they are emulator diagnostics, not a production rendering policy. Hardware backing was reported **false**. No accepted OTP or authenticated API response was fabricated.

Earlier timeouts, a locked device after reboot, a premature launch before boot completion and rejected virtual fingerprints 1 and 2 are retained in [validation](../phase-6-validation.md). They were not relabeled as passes or proven to share a single application root cause. The user unlocked the device and supplied their enrolled fingerprint; no PIN was disclosed, reset or bypassed.

Restoration evidence is fresh provider-container creation with real secure storage and server rotation. An authenticated OS process-kill/reboot restoration experiment, real-person fingerprint accuracy and physical secure hardware validation were **not executed** as part of that pass.

## 6. Performance measurements

Source: [raw performance.json](../evidence/phase-6/performance.json), [aggregates](../evidence/phase-6/performance-summary.json).

| Timed operation | n | Min ms | Median ms | Max ms |
| --- | --- | --- | --- | --- |
| Pre-OTP flow | 5 | 268.56 | 270.94 | 278.44 |
| SMTP issuance | 5 | 110.11 | 111.01 | 111.30 |
| OTP verification | 5 | 8.48 | 8.86 | 9.85 |
| Complete server MFA flow | 5 | 388.09 | **390.90** | 399.59 |
| Account retrieval | 5 | 2.34 | 2.65 | 2.97 |
| Refresh rotation | 5 | 5.20 | 5.34 | 6.09 |
| Logout | 5 | 3.60 | 4.04 | 4.56 |

These are five sequential scenarios under Jest V8 coverage instrumentation, using loopback HTTP, local PostgreSQL, an ephemeral local SMTP server and Node software EC fixtures. Pre-OTP work includes registration, enrolment, login/proof and fixture wrong-stage checks. The complete duration therefore measures that harness's local server scenario, not just a single login request. It excludes human/native biometric interaction. Component medians need not sum to the median total.

Nearest-rank p95 for five observations equals the maximum; it is not a robust tail-latency estimate. CPU/RSS observations in the raw experiment include the instrumented test process and Argon2 activity; they are not an isolated deployed-server memory budget. No comparable before/after experiment, load test, throughput estimate or production SLO was established. The native 29-second scenario is a separate measurement with different boundaries, not 390.90 ms of the same end-user task.

## 7. Build and dependency evaluation

| Check | Recorded outcome | Qualification |
| --- | --- | --- |
| Clean debug APK | Passed, 25.8 s | Normal app subsequently rebuilt/launched |
| Clean release compilation | Passed, 45.9 s | **Unsigned audit artifact**, not distributable/install-tested release |
| Release size | 52,780,174 bytes, about 52.8 MB | [Artifact inspection](../evidence/phase-6/android-artifacts.json) |
| Release signature | `apksigner` exit 1, unsigned as expected | Removed debug-sign fallback; owned signing not configured |
| Release network/backup | Cleartext/backup false, extraction rules present, debug policy absent | HTTPS placeholder `api.authvault.invalid`, not live production API |
| Runtime npm audit | Zero known advisory entries | Dated snapshot, not a security guarantee |
| Full npm audit | Six Low package entries | One deepmerge advisory propagated through Jest/ts-jest dependencies |
| Hosted Pub OSV query | 81 package versions, no advisory matches | Does not certify all native/transitive provenance |

The first debug/release builds and an intermediate failed generated-plugin build remain in the historical record. Cleaning and sequential rebuilding resolved the stale dev-only registration issue. Timings from different cache states are not evidence of optimization. No signed release, store distribution, production SMTP/TLS, physical Android or iOS execution is claimed.

## 8. Usability observations and validity

Developer inspection observed clear form hierarchy, wrapped fixture email text, safe keyboard-aware layout and visible localized feedback. Widget tests covered validation, password visibility, OTP paste/length filtering, loading/errors, reduced-motion and protected-route policy. Tested compact/landscape protected layouts included 320×568 and 568×320. Four automated checks exercised target size, labels and contrast. This does not establish all screen sizes or complete screen-reader accessibility.

No human participant study, survey, SUS score, task-success percentage, controlled usability comparison or FAR/FRR measurement exists. Local timing cannot be generalized to user completion time or production networks. The evaluation is an engineering assessment, with an instrumented single-host setup, software fixtures for server tests, a single emulator, and no independent penetration test/formal protocol proof.

## 9. Reproduction without rewriting historical evidence

Run tools sequentially in an **isolated demo checkout/copy** with its own ignored development configuration and owned local test fixtures. Do not execute aggregate/capture scripts against the submission checkout: `summarize-phase6.mjs`, `audit-pub.mjs` and the Phase 6 driver write historical evidence paths. A new run may yield different counts/timings; retain it separately with date/environment and do not silently replace the baseline.

From the isolated project root:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
flutter build apk --debug
```

From its `backend/`, after the local database prerequisites in the [demonstration guide](demonstration-guide.md):

```sh
npm ci
npm run generate
npm run lint
npm run build
npm run format:check
npm run test:coverage
```

Integration tooling verifies the local `authvault_test` database name and prepares migrations/fixtures. Never substitute a production database or disclose `.env`. Use the [native reproduction instructions](demonstration-guide.md#optional-canonical-native-retest) only with an unlocked emulator and an enrolled fingerprint. These commands are instructions, not claims of new Phase 7 execution.
