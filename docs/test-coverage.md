# Test coverage — Phase 6

Coverage was measured from executed local suites on 30 October 2026. Coverage is
execution evidence, not a security certificate. Test counts alone do not establish
complete security, and high line coverage does not imply all failure paths or races
were explored. No thresholds were lowered to hide failures.

## Backend

Command: `cd backend && npm run test:coverage`. The runner validates the isolated
`authvault_test` database, applies existing migrations and runs unit/integration
tests in one Jest process with the V8 coverage provider. Final run: **69 tests in
6 suites**, comprising 21 unit and 48 integration tests.

| Module | Lines covered / total | Line coverage | Branches covered / total | Branch coverage |
| --- | --- | --- | --- | --- |
| bootstrap/configure | 47/47 | 100.00% | 2/2 | 100.00% |
| auth | 388/388 | 100.00% | 71/87 | 81.61% |
| biometric | 407/409 | 99.51% | 93/112 | 83.04% |
| common | 74/76 | 97.37% | 19/26 | 73.08% |
| config | 57/59 | 96.61% | 41/46 | 89.13% |
| health | 15/15 | 100.00% | 4/5 | 80.00% |
| otp | 339/342 | 99.12% | 75/88 | 85.23% |
| prisma | 31/31 | 100.00% | 3/4 | 75.00% |
| session | 222/222 | 100.00% | 56/63 | 88.89% |
| users | 67/67 | 100.00% | 7/10 | 70.00% |
| **Total** | **1647/1656** | **99.45%** | **371/443** | **83.74%** |

Generated Prisma code and `src/main.ts` startup bootstrap are explicitly excluded;
`configure.ts`, DTOs, modules, guards and service/repository code remain included.
V8/ts-jest instrumentation includes structural/decorator/import lines, so the very
high line percentage must not be read as equivalent to path completeness. Missing
branches remain, particularly rare datastore, malformed internal state and platform
integration outcomes. Native hardware behavior is not represented by backend coverage.

## Flutter

Command: `flutter test --coverage`. Final run: **87 tests**, including existing
credential/biometric/navigation tests plus logout storage-failure, delayed restoration,
serialized write races, network recovery and four accessibility checks.

| Reported module | Lines covered / total | Line coverage | Branch coverage |
| --- | --- | --- | --- |
| lib/app | 70/81 | 86.42% | Not collected |
| lib/core | 100/132 | 75.76% | Not collected |
| lib/features/auth | 536/703 | 76.24% | Not collected |
| lib/features/dashboard | 41/58 | 70.69% | Not collected |
| lib/features/profile | 6/6 | 100.00% | Not collected |
| **Total reported** | **753/980** | **76.84%** | **Not collected** |

Flutter's LCOV output here reports line hits, not comparable Dart branch coverage.
“Not collected” is not zero percent. Its denominator covers libraries reported by
the tool, not every line in the repository. Unreported Dart source files are listed
in the JSON summary below; interfaces and entrypoints may have no instrumented hits.
Tests exercise the real repository adapter in some paths and controlled fixtures in
others. Fixture-authenticated widgets prove UI behavior, never backend authorization.
The local HTTP/PostgreSQL/SMTP and native tests provide separate boundary evidence.

## Native and end-to-end evidence

Kotlin/Android branch and line coverage were **not measured**: no JaCoCo/native
coverage instrumentation was introduced. Real prompt cancellation and full-flow
attempts are recorded separately in validation, including earlier failures and the
final successful 29-second manual full-flow scenario with emulator rendering conditions. They are behavioral checks, not native coverage percentages. iOS runtime,
physical-device key invalidation, real hardware attestation and production SMTP/TLS
are not covered. Provider-container recreation is tested; a full authenticated
OS-kill/reboot restoration experiment is not claimed.

## Reproduction and artifacts

```sh
flutter test --coverage
cd backend
npm run test:coverage
node scripts/summarize-phase6.mjs
```

Raw local outputs: `coverage/lcov.info`, `backend/coverage/lcov.info`,
`backend/coverage/coverage-summary.json` (generated, ignored). Reviewed aggregates:
[coverage-summary.json](evidence/phase-6/coverage-summary.json). Module percentages
sum covered/total counters; they are not averages of file percentages. Fresh runs
can produce different counts if code or tool versions change. Native integrations
are deliberately excluded from the Flutter widget LCOV count.
