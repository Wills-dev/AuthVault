# Defense preparation

## Opening overview

“AuthVault is an Android academic authentication prototype using Flutter, NestJS and PostgreSQL. The backend requires a password, a context-bound signature and a delivered email code before issuing session credentials. The stock Android client authorizes signing through a native biometric prompt. My evaluation includes automated suites, security regressions and a real emulator/local-SMTP flow. The main limitation is that the server does not verify key attestation, so it cannot prove biometric enforcement for a modified client.”

Use this as a practice outline, not a declaration of authorship on someone else's behalf. Adapt the explanation to your own work and institution's disclosure requirements. Reference facts: [report](project-report.md), [evaluation](testing-and-evaluation.md), [sources](references.md).

## Questions and defensible answers

### 1. What problem does the project address?

It addresses the gap between showing multiple authentication screens and actually enforcing ordered verification on a server. Password acceptance produces only pending context; protected data requires a completed, live session. The project also evaluates replay, concurrency and lifecycle failures that a happy-path demonstration would miss.

### 2. What is the principal contribution?

An inspectable integration of responsive UI, native signing, backend-controlled challenges/codes and revocable sessions, supported by recorded tests and explicit limitations. It is not a new cryptographic primitive or a formally proven authentication protocol.

### 3. Why choose MFA rather than only strengthening passwords?

A stronger password hash helps with offline hash compromise but cannot make a stolen correct password invalid. Additional checks can reduce dependence on that secret. Their independence and enforcement must be justified; three screens alone do not establish three independent factors.

### 4. Is AuthVault a proven three-factor system?

No. It has three sequential checkpoints. The stock client's biometric activates a possession key, while email checks inbox access. The server lacks key attestation, and compromise of the same phone or email/password ecosystem can correlate those checks. I would describe the implemented workflow rather than assign an assurance level.

### 5. Why Flutter and Riverpod?

Flutter supports a consistent Material 3 interface and reusable responsive widgets. Riverpod separates asynchronous state and dependency replacement from widgets, making transitions testable. This was an engineering selection; no benchmark proves Flutter superior to every alternative. Native security still requires Android-specific integration.

### 6. Why NestJS, PostgreSQL and Prisma?

NestJS provides explicit module/controller/service boundaries. PostgreSQL provides durable relational state and row locks for single-use security transitions. Prisma provides schema/migrations and typed access; explicit transactional checks are still required. ORM use alone does not prevent races.

### 7. How is presentation separated from business logic?

Widgets display state and dispatch actions through Riverpod controllers. Repositories/data adapters handle API and storage boundaries. NestJS services enforce authoritative verification. A screen cannot simply mark a user authenticated and override backend authorization.

### 8. How are passwords stored and checked?

They are salted Argon2id hashes, using 65,536 KiB memory, three iterations and parallelism one. Login verifies the submitted password; unknown users undergo dummy-hash verification. Passwords are not returned in account responses or stored as plaintext. These parameters still require production resource/admission testing.

### 9. What does successful password login return?

An opaque pending-attempt credential and `PENDING_BIOMETRIC`, not an access JWT or refresh token. The pending credential authorizes only appropriate MFA operations via `X-MFA-Token`; using it as Bearer does not authorize account APIs.

### 10. How does biometric enrolment work?

Registration creates pending enrolment. The stock Android client creates a credential-specific Keystore P-256 key and requests an enrolment challenge tied to its proposed public key. Native biometric authorization enables signing; successful server verification stores the public credential and reaches `ENROLMENT_COMPLETE`. The user then returns to login without a session.

### 11. Why keep the private key on the device?

The stock implementation uses a nonexportable Keystore key so the server needs only its public key and signatures. Copying the server database should not reveal that private key. This statement describes the stock implementation; without attestation the server cannot ensure every enrolling client follows it.

### 12. Is a biometric template sent to the server?

No. Android performs the match and authorizes a cryptographic operation. AuthVault transmits a public key and signature rather than fingerprint/face templates. The project therefore does not implement biometric recognition or measure biometric error rates.

### 13. How does challenge-response prevent replay?

The exact versioned payload binds a fresh nonce to purpose, user, attempt, credential, public-key hash and deadline. The server validates those bindings and consumes the challenge atomically. A copied signature cannot validly authorize a different context, and a consumed proof is rejected in the tested paths.

### 14. Does signature verification prove a fingerprint was used?

Not by itself. It proves control of the enrolled key. The stock client uses a real CryptoObject prompt, but exportable software keys can satisfy the current server. This confirmed High assurance gap requires a server-validated provenance policy, not just another client Boolean.

### 15. What would key attestation add?

It could let the server evaluate evidence about key origin and enforced properties against an explicit policy. That requires server-side chain, challenge and property verification with lifecycle maintenance, not trusting a device-supplied `hardwareBacked` flag. It is recommended work, not implemented functionality. See [Android attestation documentation](references.md#ref-7).

### 16. Did the emulator establish hardware-backed security?

No. The successful native record reports `hardwareBackedReported: false`. It establishes real OS prompt/signature behavior in that emulator. It does not establish TEE/StrongBox protection, physical-device behavior or real-person matching accuracy.

### 17. Can a password reset or missing key silently replace the device key?

No such recovery flow is implemented. Password acceptance alone must not replace an enrolled credential. Losing or invalidating the key therefore creates a practical recovery limitation, which the defense should acknowledge rather than invent a fallback.

### 18. Is the email code TOTP?

No. AuthVault generates a fresh random six-digit server code and sends it by SMTP. TOTP derives a code from a shared secret and time, while HOTP uses a counter. Storing a keyed HMAC of an emailed code does not make its generation HOTP/TOTP. See [RFC comparisons](references.md#ref-8).

### 19. Why store an HMAC instead of a plain OTP hash?

Six-digit values have only a small search space, so an unkeyed digest can be exhaustively tested after database disclosure. The keyed MAC requires an independent server secret and binds code and verification context. It does not remove the need for expiry, guessing limits and secret custody.

### 20. What stops unlimited code guessing and resending?

Expiry and single use are server-enforced. The implementation adds persistent failure counts, a five-error account lock for fifteen minutes, cooldowns, accepted-send limits and attempt/IP quotas. The code cannot outlive its pending attempt. Client countdowns only explain the server deadlines.

### 21. Is email authentication NIST-conformant or phishing-resistant here?

No such claim is made. NIST SP 800-63B-4 excludes email for out-of-band authentication, and a manually relayed code can be phished. This prototype uses email as an academic inbox-control checkpoint and has not established an AAL or phishing-resistant assurance level. See [NIST source](references.md#ref-2).

### 22. What happens if sending the email fails?

Bounded SMTP submission occurs while issuance state is locked. Rejected submission rolls back replacement and preserves an eligible previous code. However, SMTP acceptance followed by database failure can leave an unusable message in the inbox. There is no distributed transaction guaranteeing exactly-once delivery.

### 23. Where are the JWT and refresh token stored?

The access JWT remains in client memory. The opaque refresh token persists through secure storage; only its hash is kept server-side. No token is placed in a preview session or deliberately logged. Secure-storage failure prevents normal session establishment and is tested as an error path.

### 24. Why check the database if a JWT has a valid signature?

A signature confirms token integrity and claims, but alone does not show that a session has not been revoked. Protected requests also require a live session and active owned credential. This provides subsequent-request revocation at the cost of database work and stateful availability dependence.

### 25. How is refresh-token replay handled?

Rotation consumes the current token under a session-row lock and returns a replacement. Reuse of a consumed ancestor revokes the session family. This detects replay but a lost response or concurrent legitimate refresh can force reauthentication. The client serializes refresh requests to reduce accidental races.

### 26. Can two simultaneous valid requests create two sessions?

The OTP completion operation locks and rechecks state, consumes the code and creates the session in one transaction; the session attempt scalar is unique. Competing completion cannot independently reuse the consumed attempt in the exercised concurrency tests. Correct lock ordering matters as well as uniqueness.

### 27. Are all credential IDs database foreign keys?

No. For example, `AuthAttempt.verifiedCredentialId` and `AuthSession.credentialId` are UUID scalars validated by application logic. The optional `BiometricChallenge.registeredCredentialId` is an actual relation, whereas its proposed `credentialId` is not. The ER diagram deliberately distinguishes these facts.

### 28. What does logout guarantee?

It immediately clears client session state, attempts refresh-token deletion and server revocation independently, and blocks subsequent protected requests once revocation succeeds. If both local deletion and network revocation fail, durable logout across restart cannot be guaranteed. Already-authorized in-flight work may finish.

### 29. How are restoration races prevented?

Restoration refreshes server-side before granting access. Generation checks reject stale async results, refresh work is shared and storage mutations are serialized. Regression tests exercise initial-read/logout and stale cleanup/write races. Native evidence recreates the provider container, not an authenticated OS reboot.

### 30. Can a dashboard preview bypass authentication?

No. Debug-only preview routes render labeled sample layouts and do not create credentials. Real dashboard/profile routes use session guards, and their APIs enforce server authorization independently. Release builds omit preview routes.

### 31. What exactly passed in testing?

The recorded Phase 6 run passed 87 Flutter tests and 69 backend tests across six suites, plus separately documented native cancellation and full MFA scenarios. Backend totals are 21 unit and 48 integration tests. I would show the [evidence table](testing-and-evaluation.md#2-results-and-traceability), not claim those counts were rerun during documentation.

### 32. Does 99.45% coverage mean the backend is secure?

No. It means 1,647 of 1,656 reported lines executed under that coverage setup. Branch coverage is 83.74%; generated Prisma and bootstrap main are excluded, and structural lines count. Flutter reported 753/980 lines, or 76.84%; native coverage was not measured. Coverage is one indicator, not proof of attack completeness.

### 33. How should the timing figures be presented?

The manually assisted emulator scenario took 29 seconds excluding build/install. A separate five-scenario instrumented local server experiment had a 390.90 ms median and excluded human/native biometric time. Neither is a production benchmark or average human task duration; with five samples, p95 is just the maximum.

### 34. What usability study was performed?

No participant study was performed. Automated checks and developer inspection covered responsive layouts, contrast/targets/labels, keyboard handling and feedback. There is no SUS score, survey, measured human task-success rate or biometric FAR/FRR result to report.

### 35. What risks remain despite passing tests?

Missing remote key attestation, software-backed emulator keys, signup enumeration/address reservation, incomplete recovery, retention/admission controls and the recorded Low development dependency advisory remain. Physical Android, iOS, external SMTP and operational deployment are unvalidated. Passing tests do not remove these limitations.

### 36. Was the release APK ready for distribution?

No. Release compilation produced an unsigned audit artifact because owned signing properties were absent; rejection by `apksigner` was expected. Its HTTPS API was an invalid-domain placeholder. Debug launch succeeded separately, but a signed production release was not installed or validated.

### 37. What do the dependency audit results mean?

At the recorded snapshot runtime npm audit returned zero known entries, while full audit returned six Low package entries from one deepmerge advisory through development tools. The Pub query found no matches for 81 hosted versions. These are dated database checks, not a certificate of complete supply-chain safety or permission to invent a patched version.

### 38. What would you prioritize next, and is the project production-ready?

It is not production-ready. I would first define and implement remotely verifiable authenticator policy, address account initiation/recovery and dependency lifecycle, then validate physical devices and operational TLS/SMTP/signing/monitoring/backup controls. A wider approved usability and load study would follow. These are recommendations; Phase 7 does not authorize another development phase.

## Practice and evidence handling

Practice explaining the trust boundaries without source code on screen, then locate the corresponding source and evidence when challenged. Lead with the result, identify the measurement boundary, then state its limit. If a result was not measured, say so directly. Use [15 slides](presentation-outline.md) and the [demo runbook](demonstration-guide.md); keep passwords, PINs, OTPs and tokens off projected logs. Do not present a preview, software fixture or old failed run as a successful real native flow.
