# Phase 6 security audit

Date: 30 October 2026. Assessment: **academic prototype validated within the tested
scope; not ready for production**. No production infrastructure/accounts were tested
or modified. No Phase 7 work is included. This is a repository review and controlled
local security evaluation by the implementation agent, not an independent penetration
test, formal verification or security certification.

## Scope and method

Reviewed Flutter presentation/providers/repositories, GoRouter, secure storage and
network configuration; NestJS controllers, DTOs, guards, password/biometric/OTP/session
services; Prisma schema and three migrations; Android manifests, build/signing setup
and native CryptoObject channel; tests, scripts, dependencies and existing limitations.
Generated Prisma/build outputs and image assets were inspected as artifacts rather
than treated as handwritten source. A small regex source scan is triage only, not
proof that no secrets or vulnerabilities exist. Historical Git objects, external
infrastructure, iOS runtime and physical Android devices were not independently audited.

Evidence: [validation](phase-6-validation.md), [coverage](test-coverage.md),
[threat model](threat-model.md), [performance](performance-evaluation.md),
[production readiness](production-readiness.md), and raw non-secret JSON in
[evidence/phase-6](evidence/phase-6/).

## Findings and final risk register

| ID | Severity | Component | Finding | Status |
| --- | --- | --- | --- | --- |
| AV6-01 | High | Server biometric trust | Software keys can satisfy the signature stage; no attestation verifies biometric enforcement | Open architectural production blocker |
| AV6-02 | High | Android release signing | Release used the development/debug signing identity | Remediated; owned distribution signing still required |
| AV6-03 | Medium | Flutter logout | Secure-storage deletion failure prevented server revocation | Remediated; dual storage/network failure remains uncertain |
| AV6-04 | Medium | Flutter session lifecycle | Logout during initial storage read did not immediately gate restoration; stale writes could race newer credentials | Remediated |
| AV6-05 | Medium | Registration | Duplicate registration reveals email existence and unverified registration reserves an address | Confirmed, open workflow limitation |
| AV6-06 | Medium | Android backups | Backup/transfer exclusion policy was unspecified | Hardened; OEM restore behavior not physically tested |
| AV6-07 | Medium | Persistence/operations | No automated retention cleanup; consumed refresh history must survive for replay detection | Open operational work |
| AV6-08 | Medium | API availability | Auth endpoints are limited, but account reads lack an application/edge quota and Argon2 has no global admission limit | Gap confirmed; capacity/exploitation unmeasured |
| AV6-09 | Low | Secret configuration | Equivalent hex keys differing only by letter case passed distinct-key validation | Remediated |
| AV6-10 | Low | Development dependencies | deepmerge advisory affects six reported Jest/ts-jest dependency entries | Open; no nonbreaking patched release available at audit |
| AV6-11 | Informational | Platform assurance | Emulator hardware protection false; physical-device, iOS and production operations unvalidated | Explicit residual limitation |

No confirmed Critical unauthorized-account MFA bypass was found in the tested local
scope. **A biometric-assurance bypass with owned software-key fixtures was confirmed
(AV6-01).** The absence of a Critical finding is bounded evidence, not a guarantee.
It must not be summarized as “the server proves a biometric prompt occurred.”

### AV6-01 — Signature verification is not remote biometric attestation

- **Affected:** `backend/src/biometric/biometric.service.ts`, biometric DTO/protocol;
  native `BiometricKeyChannel.kt`.
- **Evidence:** Backend biometric/OTP integration fixtures generate exportable Node
  P-256 keys, enrol them through real HTTP, sign without an OS biometric operation,
  pass email OTP through actual SMTP, and receive a session. The measured test records
  `softwareKeyPathAccepted: true`. No attestation certificate/challenge/root/revocation
  validator exists. Client-reported KeyInfo is not a trusted server assertion.
- **Impact:** A modified enrolling client can use a software key without biometric
  authorization. This does not demonstrate takeover of another user's previously
  enrolled account: its password, registered private key and inbox code remain
  necessary in the tested protocol. It undermines a universal server-enforced
  three-factor/biometric guarantee and blocks that production claim.
- **Remediation:** Design server-verified hardware attestation with fresh challenge
  binding, trusted certificate-chain/revocation checks, verified key authentication
  properties, app/device policy and physical-device tests. Plan migration and recovery
  for existing unattested credentials. This changes enrolment and device support;
  it is outside this audit's limited hardening changes and is not silently implemented.
- **Status/retest:** Open architectural blocker; software-key acceptance reproduced
  in the successful server suite. Stock Android still enforces real CryptoObject
  authorization locally; no software-signing fallback was added to the mobile app.

### AV6-02 — Debug signing in release builds

- **Evidence:** Original `android/app/build.gradle.kts` assigned the `debug`
  signingConfig to `release`.
- **Impact:** An artifact presented as release did not have a private, owned
  distribution identity. Treat as a High pre-distribution weakness, not evidence
  that any published application was compromised; none was deployed here.
- **Remediation/status:** Removed the fallback. Optional ignored `android/key.properties`
  selects an owned release signing configuration. Without it, release is deliberately
  unsigned. No real credentials or new signing keys were introduced.
- **Retest:** Debug build and unsigned release compilation passed. `apksigner verify`
  rejects the unsigned release with `Missing META-INF/MANIFEST.MF`, as expected.
  This is an audit artifact, not an installable/distributable production release.

### AV6-03 — Logout skipped remote revocation on deletion failure

- **Affected:** `session_providers.dart`, logout feedback in `account_page.dart`.
- **Evidence:** Added a failing secure-store deletion fixture. Before remediation,
  logout threw before calling repository logout; the retained refresh could remain
  server-valid and restore access on a later start.
- **Remediation/status:** End local access immediately, attempt cleanup and server
  revocation independently, and report uncertainty if either fails. Do not claim
  storage cleanup succeeded when it did not. Existing live-session backend checks
  make successful server revocation reject subsequent JWT/refresh use.
- **Retest:** Regression failed before and passes after; network-failure logout and
  real E2E logout remain covered. If both storage and network are unavailable, durable
  logout cannot be guaranteed across process restart; uncertainty is explicit.

### AV6-04 — Restoration and persistence race

- **Affected:** Flutter `SessionController`.
- **Evidence:** Delayed initial storage read left state loading after logout. A
  separate controlled test interleaves an older refresh write with new credentials.
  A third failing regression reproduced invalid-session cleanup erasing a newer
  saved refresh; it passes after moving that cleanup into the same guarded queue.
- **Impact:** Logout/restoration could race, or stale cleanup could erase a newer
  saved session. No backend MFA-stage bypass was demonstrated by this local race.
- **Remediation/status:** Capture lifecycle generation before initial read, end access
  before awaited cleanup, serialize persistence/deletion, and reject/revoke stale
  results. Cleanup occurs inside the write queue before a newer write can proceed.
- **Retest:** Initial-read regression failed before and passes after. Stale-write,
  concurrent refresh, logout-during-refresh, absolute-expiry and network-recovery
  tests pass. OS process-death atomicity of platform storage is not formally proven.

### AV6-05 — Registration enumeration / address reservation

- **Evidence:** Same fixture email returns 201 on creation and 400 on duplicate.
  The database creates the unique email record before inbox ownership is established.
  New adversarial tests explicitly preserve this observation rather than asserting
  enumeration resistance. Wrong-password and unknown-user login both return the
  same 401 code/message and use Argon2 verification work.
- **Impact:** Email existence can be inferred; an unauthenticated party can reserve
  an unused address and prevent normal signup. Existing registered keys cannot be
  replaced through password login. No inbox-less completed session was obtained.
- **Remediation/status:** Open. A generic registration response, verified-address
  bootstrap, expired pending-signup reclamation and reviewed recovery workflow need
  a coordinated UX/protocol change. Rate limiting reduces volume, not the information
  leak or reservation semantics. Do not implement password/email-only key replacement.
- **Retest:** Distinguishable registration responses confirmed; generic login behavior
  and password-only replacement rejection pass.

### AV6-06 — Explicit backup exclusions

- **Evidence:** Original main manifest did not specify backup/transfer exclusions.
- **Impact:** Encrypted refresh preferences/metadata could be copied independently
  of non-exportable OS keys, creating privacy/restore failures. Plaintext token
  extraction through backup was **not** demonstrated.
- **Remediation/status:** Set `allowBackup=false`, legacy `fullBackupContent=false`
  and explicit cloud/device-transfer exclusions for local domains.
- **Retest:** Debug/release compile; compiled release manifest and retained extraction
  rule inspected. Real backup/restore and OEM enforcement remain untested.

### AV6-07 — Retention and cleanup

- **Evidence:** Expiry is checked on access, but no scheduler removes expired
  attempts/challenges/sessions, historical refresh hashes, audits or rate buckets.
- **Impact:** Unbounded growth and sensitive metadata retention. Prematurely deleting
  consumed refresh hashes of active sessions would weaken family replay detection.
- **Remediation/status:** Open. Define retention/ownership, add bounded monitored
  maintenance, preserve every consumed token until its family expires plus reviewed
  audit retention, and test cleanup against active-family replay. No user data was
  deleted or speculative production retention policy applied in this audit.
- **Retest:** Read-only schema/code review; cleanup implementation absent.

### AV6-08 — Availability admission controls

- **Evidence:** Auth/OTP/biometric routes have shared database IP quotas and specific
  account/attempt limits. `/users/me` endpoints have JWT/live-session guards but no
  application quota; there is no global Argon2 concurrency admission controller.
- **Impact:** Distributed traffic or a valid credential may consume DB/CPU resources.
  Fixed windows permit boundary bursts. Actual denial-of-service capacity was not
  measured, and a production edge limit is not known to exist.
- **Remediation/status:** Open operational/readiness gap. Configure trusted ingress
  limits, bounded concurrency/timeouts, resource budgets and alerts; measure under
  approved representative load. Preserve `trust proxy=false` unless a reviewed
  exact-proxy topology is configured.
- **Retest:** Spoofed forwarded headers cannot evade the implemented password quota;
  local latency tests are small sequential samples, not load/stress certification.

### AV6-09 — Canonical secret comparison

- **Evidence:** OTP/JWT keys are decoded from hex. Different letter casing represents
  the same bytes but previously evaded string equality checks.
- **Remediation/status:** Normalize casing when comparing independent secret values.
  No secret values or actual credentials were changed.
- **Retest:** New equivalent-hex regression passes along with short/missing/reused
  key, SMTP production-auth and bounded-cooldown environment tests.

### AV6-10 — Unpatched development-only dependency advisory

- **Evidence:** npm audit reports six Low package entries traced to
  [GHSA-gcqx-w48m-w2h4](https://github.com/advisories/GHSA-gcqx-w48m-w2h4), deepmerge
  4.3.1 prototype poisoning. Runtime-only audit reports zero known advisories.
  `npm view deepmerge version` returned 4.3.1; npm proposes breaking Jest/ts-jest
  downgrades rather than an available compatible patch.
- **Remediation/status:** Open Low. Do not load untrusted test configuration; monitor
  a reviewed compatible upstream fix. No automatic breaking upgrade/downgrade,
  advisory suppression or unsupported claim of “all dependencies secure.”
- **Retest:** Audit outputs summarized in evidence. OSV queried 81 hosted Pub package
  versions and returned no advisory matches. SDK/native transitive dependencies and
  package provenance are not comprehensively certified by these two scans.

### AV6-11 — Remaining assurance boundaries

- **Evidence/impact:** Emulator metadata reports hardware-backed false. Physical
  enrolment invalidation, strong-face devices, vendor behavior and iOS signing remain
  unvalidated. Production TLS/SMTP, secrets infrastructure, backups, alerting and
  disaster recovery were not deployed or exercised.
- **Remediation/status:** Complete the readiness gates in the production checklist;
  obtain independent review and physical-device evidence before high-assurance claims.
- **Retest:** Native cancellation and full-flow outcomes are recorded in validation;
  they do not establish real-world biometric error rates or hardware certification.

## Controls observed

Argon2id 64 MiB/three passes/one lane, random salts; expiring SHA256-hashed opaque
pending credentials; strict DTO allowlists/body limit; parameterized Prisma SQL;
locked and bound one-time ECDSA challenges; HMAC-protected six-digit OTP with expiry,
replacement, quotas and committed lockout counters; atomic OTP/session creation;
rotating high-entropy refresh hashes with replay-family revocation; fixed JWT
algorithm/issuer/audience/type/claims; live session/credential authorization for every
account endpoint; no-store/Helmet headers; secure refresh storage and RAM access
JWTs; HTTPS-only non-debug configuration; isolated debug previews. These controls
were reviewed and tested to the extent specified in coverage/validation, not formally
proven for all interleavings or deployment environments.

References: [Android attestation](https://developer.android.com/privacy-and-security/security-key-attestation),
[Android signing](https://developer.android.com/studio/publish/app-signing),
[Android backup controls](https://developer.android.com/privacy-and-security/risks/backup-best-practices),
[OWASP password storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html).
