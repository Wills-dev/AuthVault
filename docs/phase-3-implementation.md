# Phase 3 — backend foundation and password authentication

## Architecture

The Flutter foundation and Android Gradle configuration are retained. backend/ now
contains NestJS modules, DTOs, services, repositories, a Prisma schema, a committed
SQL migration and Jest tests. TypeScript strict mode, NodeNext ESM and dependency
injection are enabled. No global Nest CLI is required: tsc builds the service.

The runtime includes NestJS 12.3.2, Config 12.0.1, Prisma/client/adapter-pg 7.10.1,
pg 8.23.1, Argon2 0.45.1, class-validator 0.15.1, class-transformer 0.5.1 and Helmet
8.3.0. Exact versions are pinned in backend/package.json and package-lock.json.
Prisma 8 was a release candidate at selection time; stable 7.10.1 was selected.
The Prisma 7 client uses the PostgreSQL driver adapter and generated ESM output.
See [NestJS](https://docs.nestjs.com/cli/overview) and
[Prisma driver documentation](https://www.prisma.io/docs/orm/v7/core-concepts/supported-databases/postgresql).

Tables cover users, staged attempts, future biometric public keys, future OTP
verification MACs, future authenticated sessions/refresh hashes, audit events and
shared rate counters. Foreign keys, email/credential/token uniqueness, expiry/query
indexes and nonnegative counter constraints are committed in the migration.
Future MFA tables are persistence scaffolding only; no key, OTP, refresh or completed
session endpoints exist yet. User email normalization is also checked in SQL.

## Authentication and security

Registration validates input and persists a salted Argon2id password hash (64 MiB,
3 iterations, parallelism 1), user, pending enrolment attempt and audit event.
Database uniqueness handles concurrent registrations. Login performs Argon2
verification (including a dummy hash for unknown accounts) and creates a pending
biometric attempt with an audit event. Failed login records only a keyed identity
fingerprint. Authentication responses never expose password hashes or user internals.

Attempt secrets are 32 CSPRNG bytes, base64url encoded; only SHA-256 hashes are
stored. Default lifetime is ten minutes. Status/revocation compare hashes using
constant-time comparison and reject expired/revoked/nonpending records. No completed
session or access/refresh token is issued. Both backend account endpoints always
reject Phase 3 requests, including pending tokens presented as Bearer credentials.

Credential endpoints share database-backed per-IP/per-email fixed-window limits.
Validation rejects unknown fields and oversized inputs. Errors use a safe envelope,
server-generated request IDs and no-store headers. Unexpected failures log only
request ID, method and status. The application has no credential logging interceptor.
Configuration comes from environment; generated local secrets are ignored by Git.

## Flutter integration

Dio data sources are in auth/data/datasources; a repository parses the API contract
and maps safe errors. Domain interfaces/entities do not depend on Dio. Riverpod
owns separate login/registration async state and scoped cancellation. Navigating
away cancels in-flight form requests; duplicate submission is disabled. Password
controllers clear after success and are disposed with the form. Existing OTP UI
remains unavailable until Phase 5 and does not share credential submission state.

Success stores only an in-memory pending-MFA credential and navigates to the
biometric screen. The screen checks the pending status against the backend and
explains the remaining enrolment/biometric/OTP work. The local timer clears expired
credentials. Restart drops pending secrets and requires a new password attempt;
no resumable authenticated session is implied. A cancelled or timed-out registration
may still have committed on the server; request cancellation does not undo a completed
database transaction. Users can attempt password login after an uncertain response. Cancellation clears the local secret
and attempts server revocation; an unreachable server leaves the record valid only
until its short expiry. Dashboard/profile guards and debug-only previews remain
independent of this pending state.

API_BASE_URL is centralized in core/network/api_config.dart. Debug Android defaults
to http://10.0.2.2:3000/v1. Release must supply an HTTPS /v1 URL with --dart-define;
missing/unsafe URLs fail as configuration errors. Android production cleartext is
disabled; only the debug resource overlay permits the three loopback/emulator host
addresses. INTERNET permission is present for HTTPS in production. No Gradle change
was necessary. iOS local transport exceptions were not introduced or tested.

## Limitations

No biometric challenge/proof, email OTP, full session, refresh rotation, recovery or
real logout is implemented. The schema does not claim those controls exist. No
email ownership is verified yet. Generic password errors reduce enumeration and
use equal-cost unknown-user verification; registration outcome still differs between
new and duplicate accounts, so registration is not fully enumeration-resistant.
Rate limiting mitigates abuse but does not remove that observable difference.

Fixed-window limits permit boundary bursts and depend on a shared HMAC key/database.
IP handling deliberately ignores forwarded headers; a production proxy strategy is
required. Audit/expired-attempt/counter retention and capacity planning remain work
before public deployment. Distributed attack/DDoS protection and Argon2 concurrency
limits are outside this local prototype's validation. Remote deployments need TLS,
least-privilege infrastructure and secure secret distribution. The local cluster's
separate admin credential is for provisioning only.

Prebuilt PostgreSQL validation tooling came from a third-party package; production
should use an approved database distribution. No real-device biometric, iOS,
release-binary or performance claims are made. See phase-3-validation.md for actual
executed results. Phase 4 requires explicit approval.

The final normal Android app was built, installed and visually confirmed running.
Emulator installer/system-service instability required a data-preserving cold
restart and non-streaming installation; the failed commands and successful final
observation are recorded separately in phase-3-validation.md.
