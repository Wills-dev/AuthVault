# Architecture and security plan

## Scope

Phase 1 establishes tooling, design tokens and the app shell. It implements no
registration, login, biometric verification, OTP, sessions or protected resources.
Phase 2 replaces the temporary foundation page with authentication UI and debug
screen previews. Validation is in auth/domain, the local biometric capability
service is in core/security, and async UI state is in auth/presentation/providers.
There is still no backend or session implementation. See phase-2-implementation.md
and navigation.md for current UI boundaries.

## Layout

Keep the generated Flutter project at the root to avoid disruptive moves.

```text
lib/
  app/                 app, centralized router, theme, debug-only preview gallery
  core/widgets/        PascalCase widget directories and matching filenames
  features/            auth, dashboard and profile UI; data layers added later
    auth/              data/{datasources,models,repositories},
                       domain/{entities,repositories,usecases},
                       presentation/{pages,widgets,providers}
    dashboard/         data, domain, presentation
    profile/           data, domain, presentation
  core/                errors, network, security, storage, utils as needed
android/               Android biometric signing bridge in Phase 4
ios/                   iOS biometric signing bridge in Phase 4
backend/               NestJS service introduced in Phase 3
  src/                 auth, users, biometric, otp, mail, logging, prisma
  prisma/              schema and committed migrations
  test/                integration and security tests
docs/                  contracts, architecture, evaluation and setup
```

Only populated directories are created. Widgets call providers; providers coordinate
use cases and repositories; repositories call data sources. HTTP belongs only in
Dio data sources. Domain entities do not depend on Flutter or wire formats. Avoid
one-line use cases without business rules. Immutable state will distinguish signed
out, pending enrolment, pending biometrics, pending OTP, and authenticated states.
GoRouter redirects improve UX; backend guards are the authorization boundary.

Riverpod uses explicit providers without code generation to keep tooling small.
GoRouter owns routes; Dio will own timeouts, error translation and serialized token
refresh. No request/response logging interceptor may expose credentials. Secure
storage will hold refresh tokens; access tokens should remain in memory. Pending
MFA credentials are separate from authenticated sessions. Restart must resume only
server-valid attempts or return to login. An unknown or expired state fails closed.

## Server authority

NestJS modules own their corresponding responsibilities. Auth orchestrates stage
transitions; Users owns account data; Biometric verifies key enrolment and signed
challenges; Otp owns issue/expiry/consumption; Mail delivers; Logging records
redacted audit events; Prisma owns persistence. DTO validation rejects unknown
fields. A centralized exception filter returns the documented error envelope.

Use Argon2id for passwords, a CSPRNG for six-digit OTPs, and a keyed HMAC for OTP
verification material (a plain hash of a six-digit code is cheap to brute-force).
Bind OTP material to user and attempt. Five-minute expiry, resend cooldown, send
limits, attempt limits and temporary lockouts are server controlled. Delivery and
resend failures need transactional/outbox design so an undelivered code does not
silently leave an inconsistent attempt. Enforce limits across server instances.

Persist MFA stage changes and challenge/OTP consumption atomically. Concurrent
replay requests must allow at most one success. Access JWTs are short lived and
have explicit issuer/audience/algorithm checks. Opaque refresh tokens are hashed,
rotated in a transaction, and grouped into a token family; reuse revokes the family.
Logout revokes the family. Define access-token revocation behavior explicitly in
Phase 6 rather than implying logout invalidates every stateless JWT immediately.

## Biometric trust boundary

local_auth alone cannot prove biometrics to the server. Phase 4 needs native method
channels and a non-exportable P-256 private key: Android Keystore signing unlocked
through BiometricPrompt CryptoObject with strong biometrics, and iOS Secure Enclave
with biometric-current-set access control. Verify platform support and fail closed;
never silently substitute a software key or device PIN. The backend stores public
keys and verifies ECDSA/SHA-256 over exact, versioned server-issued challenge bytes.
Encoding, signature format, purpose, expiry and device binding must be specified
before implementation. Enrolment requires proof of possession tied to the newly
created account, and cannot overwrite a registered key using password alone.

A valid signature proves possession of a key; it does not independently establish
hardware enforcement or app integrity. Document attestation and compromised-device
limitations. No raw biometric data leaves the OS. Enrolment changes invalidate keys
where supported; lost/invalidated keys fail closed. Recovery is outside prototype
scope and must not become an MFA bypass.

Simulation will use separate test/demo adapters, separate backend configuration and
test keys. Production build/start checks must reject simulation; debug-only asserts
are insufficient. There is no simulation implementation or toggle in Phase 1.

## Intended sequence

```mermaid
sequenceDiagram
  participant M as Mobile
  participant K as OS protected key
  participant A as NestJS
  participant E as Email
  M->>A: Register name/email/password
  A-->>M: Restricted enrolment attempt + challenge
  M->>K: Create key and authorize signing
  K-->>M: Public key + enrolment signature
  M->>A: Public key + proof
  A-->>M: Enrolled; return to login
  M->>A: Email + password
  A-->>M: Restricted MFA attempt + biometric challenge
  M->>K: Biometric authorized signature
  K-->>M: Signature
  M->>A: Attempt + signature
  A->>E: Deliver single-use OTP
  A-->>M: OTP stage + expiry/cooldown
  M->>A: Attempt + OTP
  A-->>M: Access token + rotating refresh token
  M->>A: Protected request with access token
  A-->>M: Dashboard data
```

Registration never grants a full session. Pending-attempt credentials must never be
accepted by access-token guards. Remote APIs require HTTPS; development exceptions
must be narrowly scoped. Backend logs omit passwords, OTPs, tokens and private keys.
