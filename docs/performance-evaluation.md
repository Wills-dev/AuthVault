# Performance evaluation — Phase 6

These are **local measurements**, not production SLOs, biometric-speed measurements
or claimed improvements. There is no comparable before/after benchmark for the
hardening changes. Phase 5 readiness-request samples are a different workload and
are not used as a performance baseline.

## Method

The measured integration scenario in `backend/test/otp.integration.spec.ts` executes
five sequential complete server flows in the isolated local PostgreSQL database.
NestJS is hosted in the Jest process; Supertest uses loopback HTTP, Nodemailer sends
to an actual ephemeral loopback SMTP server, and codes are parsed from that received
message. The test deliberately uses exportable software P-256 keys; **it measures
no Android prompt, physical biometric processing or human inbox/typing time**.
Coverage instrumentation and test-runner overhead are present. The pre-OTP phase
includes registration, enrolment challenge/proof, password login and login challenge/
proof. HTTP setup overhead is included. The fixture's wrong-stage check also occurs
within that pre-OTP sequence. Limits are reset only between samples in the isolated
test database, outside timing; this is not a production limit-bypass recommendation.

| Measured segment | n | Minimum ms | Median ms | Maximum ms | Nearest-rank p95 ms |
| --- | --- | --- | --- | --- | --- |
| preOtpFlowMs | 5 | 268.56 | 270.94 | 278.44 | 278.44 |
| smtpIssueMs | 5 | 110.11 | 111.01 | 111.30 | 111.30 |
| otpVerifyMs | 5 | 8.48 | 8.86 | 9.85 | 9.85 |
| completeMfaMs | 5 | 388.09 | 390.90 | 399.59 | 399.59 |
| accountMs | 5 | 2.34 | 2.65 | 2.97 | 2.97 |
| refreshMs | 5 | 5.20 | 5.34 | 6.09 | 6.09 |
| logoutMs | 5 | 3.60 | 4.04 | 4.56 | 4.56 |

For only five samples the nearest-rank p95 equals the maximum; it is not a reliable
estimate of tail latency under load. No parallel-user, saturation, distributed-edge,
remote database or external SMTP benchmark was performed. No pass/fail security
conclusion is derived from these timings.

## Resources and query observations

The instrumented Node/Jest process RSS was 404.03 MiB before and 390.31 MiB after the five-flow block. CPU deltas were 1405.63 ms user and 62.13 ms system. These include the test runner and earlier fixtures; they are not standalone NestJS resource budgets, a leak diagnosis or peak-memory measurements.

The schema has unique email/token-hash keys, attempt/session primary keys, challenge
attempt/date indexes and user/date audit indexes. The sample EXPLAIN plan for session
primary-key lookup is saved in raw evidence. A small local table may legitimately
use a sequential scan; no production index improvement is claimed from that sample.
Every protected read checks a live session and credential; dashboard identity and
security requests add database work. Synchronous bounded SMTP holds attempt/user/
credential locks, so provider latency can serialize same-user requests. No global
cleanup/admission/load profile was implemented; these remain production work.

## Startup, UI and network observations

Phase 6 debug APK assembly completed in 12.7 seconds; the first unsigned release
assembly took 95.0 seconds. After generated-output cleanup, final sequential builds
took 25.8 seconds (debug) and 45.9 seconds (release). Different cache/build conditions
prevent interpreting this as a performance improvement. These are build times, not application startup latency.
Native cancellation completed in 4 seconds excluding build/install. The successful
manual native full-flow scenario completed in 29 seconds, excluding its 20.8-second
build and 3.5-second install; this includes operator and UI time and is not a pure
biometric latency measurement. Earlier failed attempts and rendering conditions are recorded in validation;
failed waits must not be presented as successful authentication completion times.

Loading indicators, duplicate-submission prevention, safe error feedback, explicit
restoration retry and network-recovery fixtures were exercised. Accessibility
checks cover Android target sizes, actionable labels and text contrast on welcome,
login, registration and OTP. Existing large-text, keyboard and responsive-layout
checks remain; this is not a screen-reader usability study or WCAG certification.

## Reproduction

```sh
cd backend
npm ci
npm run generate
npm run test:coverage
node scripts/summarize-phase6.mjs
```

The runner requires the documented isolated `TEST_DATABASE_URL` and development
SMTP config for other tests; the measured test creates its own ephemeral receiver.
Do not run it against production. Results are overwritten in ignored
`backend/.test-results/phase-6-performance.json`. Final reviewed snapshots:
[raw samples/resources/query plan](evidence/phase-6/performance.json) and
[summary](evidence/phase-6/performance-summary.json). Recompute percentiles from the
new samples rather than reusing this table if conditions change.
