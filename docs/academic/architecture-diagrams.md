# Architecture diagrams

Seven diagrams describe the implemented system as reviewed on 30 October 2026. They are text-based design views, not additional test evidence. Source contracts: [API](../api-contract.md), [schema](../../backend/prisma/schema.prisma), [router](../../lib/app/router/app_router.dart), [biometric service](../../backend/src/biometric/biometric.service.ts), [OTP service](../../backend/src/otp/otp.service.ts), [session service](../../backend/src/session/session.service.ts).

## 1. High-level system architecture

```mermaid
flowchart LR
  Person[User] --> UI[Flutter Material 3 screens]
  subgraph Android[Android client boundary]
    UI --> State[Riverpod state and repositories]
    State --> Router[GoRouter UI guards]
    State --> Dio[Dio API adapters]
    State --> Native[Native biometric MethodChannel]
    Native --> Prompt[BiometricPrompt CryptoObject]
    Prompt --> Keys[Android Keystore P256 signing key]
    State --> Store[Secure storage refresh token]
    State --> RAM[Access JWT in memory]
  end
  Dio -->|HTTPS required for release; local HTTP in debug| API[NestJS v1 API]
  subgraph Server[Backend trust boundary]
    API --> Modules[Auth Biometric OTP Session Users]
    Modules --> Prisma[Prisma and row-lock transactions]
    Prisma --> DB[(PostgreSQL)]
    Modules --> Mail[Nodemailer SMTP transport]
  end
  Mail --> SMTP[SMTP server]
  SMTP --> Inbox[Email inbox or local test mailbox]
  Inbox -->|User enters delivered code| UI
  Keys -.->|Public key and signatures only; no attestation| Dio
```

The debug mailbox is loopback tooling, not a production delivery provider. Native key restrictions are client-side; the server cannot establish hardware backing from the submitted public key/signature.

## 2. Authentication sequence

```mermaid
sequenceDiagram
  actor U as User
  participant A as Flutter app
  participant K as Android prompt and Keystore
  participant B as NestJS API
  participant D as PostgreSQL
  participant M as SMTP mailbox
  Note over A,D: Previously enrolled credential, enrolment shown separately below
  U->>A: Submit email and password
  A->>B: POST /auth/login
  B->>D: Verify Argon2id hash and create attempt
  B-->>A: Pending token and PENDING_BIOMETRIC only
  A->>B: POST /biometric/challenge with X-MFA-Token
  B->>D: Bind and store single-use challenge
  B-->>A: Exact versioned payload and expiry
  A->>K: Sign exact payload with CryptoObject
  U->>K: Native biometric authorization
  K-->>A: ECDSA signature or cancellation/failure
  A->>B: POST /biometric/verify with proof
  B->>D: Verify key ownership, signature and consume challenge
  B-->>A: PENDING_OTP only
  A->>B: POST /otp/send
  B->>M: Submit randomly generated email code
  B->>D: Commit bound code MAC after SMTP acceptance
  B-->>A: Challenge ID, expiry and resend time, no code
  M-->>U: Delivered message in controlled inbox
  U->>A: Enter six-digit code
  A->>B: POST /otp/verify
  B->>D: Atomic consume, complete attempt, create session and audit
  B-->>A: Access JWT and opaque refresh token
  A->>A: Persist refresh securely before accepting session
  A->>B: GET /users/me with Bearer JWT
  B->>D: Check live session and active owned credential
  B-->>A: Actual account data
```

All unsuccessful proof/code paths fail closed; this success-path diagram does not turn SMTP acceptance into a delivery guarantee. A secure-storage failure prevents the client from treating session establishment as successful.

## 3. Biometric enrolment and challenge-response

```mermaid
flowchart TD
  R[Register account and obtain PENDING_ENROLMENT token] --> Cap{Strong biometric available and enrolled?}
  Cap -->|No| Unavailable[Explain unavailable state; no signature]
  Cap -->|Yes| Generate[Create per-account credential UUID and Keystore P256 key]
  Generate --> EnrolChallenge[Request ENROLMENT challenge with proposed public SPKI key]
  Login[Password accepted for existing account] --> LoginChallenge[Request LOGIN challenge for registered credential]
  EnrolChallenge --> Bound[Server binds purpose user attempt credential key hash nonce and expiry]
  LoginChallenge --> Bound
  Bound --> Sign[Native prompt authorizes SHA256withECDSA over exact payload]
  Sign -->|Cancel or failure| Stop[No accepted proof; no session]
  Sign -->|Signature| Verify[Server checks context expiry ownership and signature under locks]
  Verify -->|Invalid expired or consumed| Reject[Reject without advancing MFA]
  Verify -->|Valid ENROLMENT| Enrolled[Store public credential; consume challenge; ENROLMENT_COMPLETE]
  Enrolled --> Return[Return to login; no session issued]
  Verify -->|Valid LOGIN| Otp[Consume challenge; bind verified credential; PENDING_OTP]
```

The server has **no key-attestation verification**. The stock debug client may use an OS-managed software-backed key; the nondebug client additionally checks local hardware metadata. Neither local check proves provenance to a modified-client-resistant server. Missing/revoked keys are not silently replaced using only the password.

## 4. OTP verification and MFA completion

```mermaid
flowchart TD
  Pending[Authenticated pending context at PENDING_OTP] --> Limits{Account IP cooldown and send limits allow?}
  Limits -->|No| Rate[Reject; retain permitted state]
  Limits -->|Yes| Lock[Lock attempt user and active credential]
  Lock --> Generate[Generate random six digits; bind HMAC to context]
  Generate --> SMTP{Bounded SMTP submission accepted?}
  SMTP -->|No| Rollback[Roll back replacement; previous usable code retained]
  SMTP -->|Yes| Commit[Commit new MAC and invalidate previous challenge]
  Commit --> Enter[User submits challenge ID and code]
  Enter --> Check{Valid context active key unexpired unused code and matching MAC?}
  Check -->|Wrong| Failure[Persist failure count; enforce exhaustion and user lockout]
  Check -->|Expired or invalid| Rejected[Reject without session]
  Check -->|Yes| Atomic[One transaction: consume OTP, COMPLETED, session, refresh hash, audit]
  Atomic --> Tokens[Return short access JWT and rotating refresh token]
  Tokens --> Client[Securely persist refresh token then show protected dashboard]
```

Default code lifetime is at most five minutes and never exceeds the pending attempt. Five incorrect codes trigger the account lock; send cooldown defaults to 60 seconds and only three accepted sends are allowed per attempt. SMTP is external to PostgreSQL: acceptance followed by a database failure can still produce an unusable email. There is no distributed transaction or durable plaintext outbox.

## 5. Database entity relationships

```mermaid
erDiagram
  User ||--o{ AuthAttempt : owns
  User ||--o{ BiometricCredential : registers
  User ||--o{ AuthSession : owns
  User |o--o{ AuditEvent : optionally_identifies
  AuthAttempt ||--o{ BiometricChallenge : binds
  AuthAttempt ||--o{ OtpChallenge : binds
  BiometricCredential |o--o{ BiometricChallenge : registeredCredentialId
  AuthSession ||--o{ RefreshToken : contains
  User {
    uuid id PK
    string email UK
    string fullName
    string passwordHash
    datetime otpLockedUntil
  }
  AuthAttempt {
    uuid id PK
    uuid userId FK
    string tokenHash UK
    enum stage
    datetime expiresAt
    uuid verifiedCredentialId "nullable scalar; no FK"
  }
  BiometricCredential {
    uuid id PK
    uuid userId FK
    string deviceId "unique with userId"
    string publicKey
    datetime revokedAt
  }
  BiometricChallenge {
    uuid id PK
    uuid attemptId FK
    uuid registeredCredentialId FK "nullable LOGIN relation"
    uuid credentialId "scalar proposed or existing ID"
    enum purpose
    string payload
    string publicKeyHash
    datetime expiresAt
    datetime consumedAt
  }
  OtpChallenge {
    uuid id PK
    uuid attemptId FK
    string codeMac
    int failures
    datetime expiresAt
    datetime resendAt
    datetime invalidatedAt
    datetime consumedAt
  }
  AuthSession {
    uuid id PK
    uuid userId FK
    uuid attemptId UK "nullable scalar; no FK"
    uuid credentialId "nullable scalar; no FK"
    datetime expiresAt
    datetime revokedAt
  }
  RefreshToken {
    uuid id PK
    uuid sessionId FK
    string tokenHash UK
    datetime expiresAt
    datetime consumedAt
    datetime revokedAt
  }
  AuditEvent {
    uuid id PK
    uuid userId FK "nullable; on delete set null"
    string kind
    string subjectHash
    datetime createdAt
  }
  RateLimit {
    string key PK "HMAC identifier; no user FK"
    int count
    datetime expiresAt
  }
```

This is a selected-field view of all nine models, not a migration script. Solid relationships above correspond to actual Prisma foreign keys. `AuthAttempt.verifiedCredentialId`, `AuthSession.attemptId`, `AuthSession.credentialId` and `BiometricChallenge.credentialId` are application-validated scalar references, **not additional database foreign keys**. The optional registered-credential relation supports enrolment before a credential exists. The session's unique attempt scalar prevents two sessions for one completed attempt. Passwords, raw OTPs and private biometric keys are not stored as plaintext in this schema.

## 6. Session lifecycle

```mermaid
stateDiagram-v2
  [*] --> SignedOut
  SignedOut --> Pending: Password accepted
  Pending --> SignedOut: Abandon revoke or expire
  Pending --> Establishing: Biometric proof then valid OTP
  Establishing --> Active: Refresh securely persisted
  Establishing --> SignedOut: Persistence failure and cleanup
  Active --> Refreshing: Access renewal or startup restoration
  Refreshing --> Active: Rotate refresh and persist replacement
  Refreshing --> RestoreGate: Network or recoverable storage error
  RestoreGate --> Refreshing: Explicit retry
  RestoreGate --> SignedOut: Explicit sign out
  Refreshing --> SignedOut: Invalid expired or revoked refresh
  Active --> SignedOut: Logout or absolute session expiry
  Active --> Revoked: Refresh replay or credential revocation
  Revoked --> SignedOut: Next guarded request or session reconciliation
```

Access JWTs are in memory; only refresh tokens persist in secure storage. Every protected request also checks the database session and credential. Reuse of a consumed refresh token revokes its session family, including the winner of a concurrent rotation. Logout clears UI state immediately and independently attempts storage deletion and server revocation. If both fail, durable logout across restart cannot be guaranteed. Already-authorized in-flight requests may finish. Startup restoration obtains server approval before granting access; the executed native retest recreated the provider container rather than killing the OS process.

## 7. Application navigation

```mermaid
flowchart TD
  Start[App start] --> Restore{Restoration pending or error?}
  Restore -->|Yes| Gate["/restore: wait retry or sign out"]
  Restore -->|No session| Welcome["/ Welcome"]
  Restore -->|Valid server-refreshed session| Dashboard["/dashboard: protected"]
  Welcome --> Login["/login"]
  Welcome --> Register["/register"]
  Login --> Register
  Register --> Login
  Register -->|Pending enrolment only| Bio["/biometric"]
  Bio -->|Enrolment complete| Login
  Login -->|Pending biometric only| Bio
  Bio -->|Verified login proof| OTP["/otp"]
  OTP -->|Verified code and persisted session| Dashboard
  Dashboard --> Profile["/profile: protected"]
  Profile --> Dashboard
  Dashboard -->|Logout| Login
  Profile -->|Logout| Login
  Direct[Signed-out direct protected navigation] --> Login
  Welcome -.-> Preview["/preview: debug only"]
  Preview -.-> PD["/preview/dashboard: sample data"]
  Preview -.-> PP["/preview/profile: sample data"]
```

`/biometric` and `/otp` are navigable screens, but usable actions require their appropriate server-controlled pending context; opening a page does not grant a session. Authenticated visits to guest authentication routes redirect to the dashboard. Unknown routes render Welcome. Preview routes are omitted in release and do not issue credentials or authorize backend requests. The diagram shows application navigation, not an implemented Android deep-link registration.
