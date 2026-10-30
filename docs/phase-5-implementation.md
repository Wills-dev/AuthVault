# Phase 5 — Email OTP and completed sessions

Flutter feature boundaries, Riverpod, GoRouter, Dio and Android Keystore proof are
preserved. OtpModule owns issuance/verification and SMTP delivery; SessionModule
owns JWTs, refresh families and authorization. UsersModule exposes guarded real
identity/security data. No Phase 6 work is included.

## Complete sequence

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter app
    participant Key as Android Keystore / biometric prompt
    participant API as NestJS API
    participant DB as PostgreSQL
    participant SMTP as Configured SMTP provider
    participant Inbox as User inbox
    User->>App: Register name, email, password
    App->>API: POST /auth/register
    API->>DB: Argon2id user + PENDING_ENROLMENT + audit
    API-->>App: Expiring opaque pending credential
    App->>Key: Create auth-per-use P-256 key
    App->>API: Request enrolment challenge for public key
    API->>DB: Persist bound nonce/payload
    API-->>App: Exact bytes to sign
    App->>Key: Biometric-authorized CryptoObject signature
    Key-->>App: Signature (private key never exported)
    App->>API: Enrol proof
    API->>DB: Consume challenge, register public key, ENROLMENT_COMPLETE
    User->>App: Login email + password
    App->>API: POST /auth/login
    API->>DB: Verify password; create PENDING_BIOMETRIC attempt
    API-->>App: New pending credential
    App->>API: Request LOGIN challenge
    API-->>App: Bound nonce/payload
    App->>Key: Biometric-authorized signature
    App->>API: POST /biometric/verify
    API->>DB: Verify signature, consume nonce, bind credential, PENDING_OTP
    App->>API: POST /otp/send with pending credential
    API->>DB: Lock attempt, user and verified credential
    API->>SMTP: Random six-digit code, bounded SMTP request
    SMTP-->>API: Accepted or rejected
    SMTP->>Inbox: Delivery attempt (acceptance is not inbox confirmation)
    API->>DB: Store keyed digest; replace old challenge; audit acceptance
    API-->>App: Challenge ID, expiry, resend timestamp (never code)
    User->>App: Enter/paste received code
    App->>API: POST /otp/verify
    API->>DB: Lock, validate digest/limits, consume once, COMPLETED
    API->>DB: Create session and refresh hash + MFA_COMPLETED audit
    API-->>App: Short-lived JWT + opaque refresh credential
    App->>App: Securely persist refresh; keep JWT in memory
    App->>API: GET /users/me and /users/me/security with JWT
    API->>DB: Check live session and credential; retrieve account data
    API-->>App: Real dashboard identity and latest completed MFA
    Note over App,DB: Restart or access expiry: atomically rotate saved refresh credential
    App->>API: POST /auth/refresh
    API->>DB: Lock session; consume refresh; issue new hashed refresh
    API-->>App: New JWT and refresh credential
    User->>App: Logout
    App->>API: POST /auth/logout
    API->>DB: Revoke live session and refresh family
    App->>App: Clear local credentials and protected navigation
```

## OTP invariants

CSPRNG `randomInt(0, 1_000_000)` produces padded six digits. HMAC-SHA256 under a
separate environment secret binds challenge ID, user ID, attempt ID, verified
biometric credential ID and code. Codes are never returned, persisted or logged by
the authentication service. Nodemailer necessarily handles plaintext in memory and
the receiving mailbox contains the email; protect SMTP and mailbox access.

Only unexpired PENDING_OTP attempts with a valid opaque token and a non-revoked,
owned, server-verified biometric credential may issue or verify. Existing Phase 4
pending attempts without the new binding fail closed. Row locks serialize each
attempt, user lockout and credential check. Five wrong guesses exhaust a challenge
and lock the user for fifteen minutes across attempts. Failed guesses are committed
before returning errors. Invalid cross-attempt challenge IDs cannot consume a code.

Code lifetime is five minutes **or the pending attempt deadline, whichever is
sooner**; the UI displays the server deadline. Resend defaults to sixty seconds,
configurable from 60–600. At most three accepted sends per attempt; per-attempt
request limits are six sends and fifteen verification requests per ten-minute
bucket, plus the existing thirty requests/IP/minute and account password limits.
New SMTP-accepted issuance invalidates old codes. OTP consumption, attempt
completion, session/refresh-hash creation and completion audit share one transaction.
Concurrent verification can create only one session (also unique by attempt ID).

SMTP runs inside a bounded transaction while locks are held; rejection rolls back
replacement, preserving any earlier valid code. SMTP and PostgreSQL cannot commit
atomically: provider acceptance followed by transaction failure may yield an unusable
email. A network-lost verification response can similarly complete MFA without the
client receiving credentials. Restart sign-in in that case; no insecure completion
recovery endpoint is added. No plaintext durable outbox is introduced.

## Session invariants

HS256 JWTs use a distinct 32-byte secret, fixed issuer `authvault`, audience
`authvault-mobile`, type `at+jwt`, subject, session ID, JWT ID and five-minute expiry
(capped at session expiry). Opaque random 32-byte refresh credentials are stored
only as SHA256 hashes; their entropy makes unkeyed hashing suitable here.
Sessions have a fixed seven-day absolute expiry; rotation does not extend it.
Refresh locks the session and re-reads token state before consuming and replacing.
Reuse of a consumed token commits revocation of the entire family before returning
401. Two simultaneous uses yield one success and one rejection; the replay also
revokes the winner. No grace interval conceals replay.

**JWT validation includes a live database session and credential check on every
protected request.** Logout therefore rejects subsequent requests using an otherwise
unexpired JWT. A request already authorized may finish. This is additional stateful
revocation, not a claim that a stateless JWT can be erased. Access expiry normally
triggers refresh; expired/revoked refresh state clears local access and redirects.
The client also schedules the absolute session deadline to remove cached dashboard
access without waiting for another API request.
Datastore availability is required for protected resources. Logout is idempotent
for an unknown refresh credential and can revoke using a known consumed ancestor.

Flutter stores only refresh credentials using flutter_secure_storage; access JWTs
and pending MFA credentials stay in RAM. Restoration rotates the saved refresh
before granting UI access. A shared refresh future prevents concurrent local token
reuse. Automatic Riverpod restoration retries are disabled. On network failure,
restoration remains gated with explicit retry/sign-out; no response is treated as
success. A lost rotation response may cause an explicit retry to trigger replay
revocation and require login. Failure to save newly issued credentials revokes them
best-effort and fails closed. Logout clears local state even on network failure and
reports when server revocation cannot be confirmed. Generation checks prevent an
in-flight refresh from restoring access after logout.

## UI and separation

OTP entry uses numeric formatting, six-digit limit, paste/autofill, keyboard submit,
server countdown, resend gate and safe invalid/expired/exhausted/network feedback.
Codes clear on replacement, completion, attempt change and disposal. Requests live
in the repository/controller, never widgets. Dashboard/profile display backend
identity, active credential/session counts and the latest MFA_COMPLETED timestamp;
no sample activity is presented as real. Preview pages stay under debug-only
`/preview/*`, do not create sessions and cannot authorize backend resources.

## Security and operational limits

- Email OTP is not phishing-resistant. Email delivery/availability depends on the
  configured SMTP provider and recipient. Only controlled local SMTP was tested.
- Android emulator evidence proves native prompt/signature execution, not hardware
  trust. Server attestation, physical-device validation, iOS signing, recovery,
  password reset and credential replacement remain Phase 4 limitations.
- Production TLS termination, restricted database roles, secret rotation/key IDs,
  backups and retention/cleanup of attempts, tokens, audit and rate counters remain
  operational work. JWT key rotation currently invalidates all JWTs signed by the
  previous single key; OTP-key replacement invalidates outstanding codes.
- Mobile secure storage protects data at rest under OS guarantees; rooted or
  compromised devices and stolen bearer credentials remain threats. App restart
  does not preserve unfinished MFA or entered OTPs.
- Database locks plus synchronous SMTP bound throughput; measure under production
  load before scaling. No production latency, availability, biometric accuracy or
  external inbox delivery claims are made.

References: [Nodemailer SMTP](https://nodemailer.com/smtp),
[jose JWT signing/validation](https://github.com/panva/jose),
[Mailpit development SMTP](https://mailpit.axllent.org/docs/configuration/smtp/).
