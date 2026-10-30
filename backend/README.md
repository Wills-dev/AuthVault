# AuthVault backend — Phase 6 audit

NestJS 12.3.2, strict TypeScript, PostgreSQL and Prisma 7.10.1. Password and biometric stages return expiring pending credentials. Email OTP completes
MFA and issues a five-minute JWT and rotating seven-day session refresh credential.

## Prerequisites

Node 24.22.1 and npm 11.19.1 were inspected. PostgreSQL and Docker were initially
absent from PATH. Standard macOS installation:

```sh
brew install postgresql@17
```

Docker alternative (when Docker Desktop/Engine is installed):

```sh
cd backend
# First create an ignored .env with a newly generated POSTGRES_PASSWORD and
# POSTGRES_USER=authvault, POSTGRES_DB=authvault. Never reuse example credentials.
docker run --name authvault-postgres --env-file .env -p 127.0.0.1:55432:5432 -d postgres:17
```

The local helper below avoids a system-wide service and generates its own random
application/admin credentials. It creates an ignored .env only if none exists and
refuses an existing unrelated database URL. It creates authvault and authvault_test
with a non-superuser application role. Do not use development admin credentials in
production.

```sh
cd backend
npm ci
npm run db:local
npm run generate
npm run db:migrate
npm run build
npm start
```

The default POSTGRES_BIN is `/opt/homebrew/opt/postgresql@17/bin`. For Postgres.app,
set `POSTGRES_BIN=/Applications/Postgres.app/Contents/Versions/17/bin` on the local
helper command. Other environments can provide an existing DATABASE_URL and apply
migrations without using the helper. `.env.example` documents required settings.

Homebrew provisioning stalled on this host. Validation instead used development-only
prebuilt upstream PostgreSQL **17.10** binaries from the third-party
`@embedded-postgres/darwin-arm64@17.10.0-beta.17` distribution. The package wrapper
has a beta version; `postgres --version` reported PostgreSQL 17.10. It is installed
only in ignored `.local/pg-tools`, not in backend runtime dependencies. To reproduce
this macOS arm64 fallback:

```sh
cd backend
npm install --prefix .local/pg-tools --ignore-scripts --save-exact @embedded-postgres/darwin-arm64@17.10.0-beta.17
(cd .local/pg-tools/node_modules/@embedded-postgres/darwin-arm64 && node scripts/hydrate-symlinks.js)
POSTGRES_BIN="$PWD/.local/pg-tools/node_modules/@embedded-postgres/darwin-arm64/native/bin" npm run db:local
```

The local cluster listens only on 127.0.0.1:55432, uses SCRAM authentication and
stores data in `.local/postgres`. Stop it with the matching pg_ctl binary:

```sh
"$POSTGRES_BIN/pg_ctl" -D "$PWD/.local/postgres" -m fast -w stop
```

Set POSTGRES_BIN to the actual binary directory before using that command. No
Homebrew background service was enabled. No production database is created.

## Checks

```sh
npm run format:check
npm run lint
npm run generate
npm run build
npm test
npm run smoke
```

npm test runs unit tests then migrates the separately configured authvault_test
and runs real HTTP/PostgreSQL tests. It refuses a URL that does not name that test
database. Tests use generated users and clean their own fixture rows. Never run
them against shared production data. npm run smoke needs the local development
server running, generates temporary credentials and removes its account afterward.

Modules: ConfigModule validates environment; PrismaModule owns database lifecycle;
UsersModule owns account lookup and fail-closed protected endpoints; AuthModule
owns DTOs, hashing, repositories, attempts and rate limits; HealthModule checks
liveness/readiness. Registration and login each persist their attempt and audit
event transactionally. Secrets never appear in API logs or responses other than
the one-time delivery of the newly created opaque attempt credential.

See [API contract](../docs/api-contract.md), [Phase 3 notes](../docs/phase-3-implementation.md)
and [validation](../docs/phase-3-validation.md). Remote deployment requires TLS
termination, a restricted database role/connection, secret management and retention
policies. Phase 6 has not started.


Phase 4 adds BiometricModule and migration 202610300002_biometric_challenges.
Run npm run generate, npm run db:migrate, npm run build and restart the local
server after updating. npm test now includes real-database biometric proof,
expiry, cross-user, stage, replay, revocation and concurrency tests. Test software
keys validate the server protocol only and are not native biometric evidence.

Registration/login/status include subjectId for native credential lookup.
Enrolment ends at ENROLMENT_COMPLETE; login proof ends at PENDING_OTP. OTP completion is now required before protected account endpoints accept access credentials.
See ../docs/biometric-security-design.md for the explicit lack of server attestation,
admin-only revocation policy and recovery/physical-device limitations. See the Phase 5 notes below.


## Phase 5 setup and delivery

Existing development installations: run `node scripts/configure-local-auth.mjs` once
before restarting. Fresh `npm run db:local` creates the Phase 5 settings too.
Existing values are preserved. Generate each authentication/HMAC key independently
with 32 cryptographically random bytes encoded as hex; `.env.example` contains only
placeholders. Production should inject secrets from a secret manager.

```sh
npm ci
npm run generate
npm run db:migrate
npm run build
# Terminal 1, local development only:
node scripts/mailbox.mjs
# Terminal 2:
npm start
```

The bundled mailbox requires dev dependencies (`smtp-server`), binds SMTP 1025 and
HTTP 8025 to loopback, retains at most 50 messages in RAM and exposes only messages
from the last ten minutes. It never forwards mail or logs message contents. Stop it
after testing. Do not expose it on a shared/public interface. The mobile production
code never reads it; only integration test code uses `/messages`.

Mailpit alternative (not executed on this Docker-less host):

```sh
docker compose -f compose.mailpit.yml up -d
```

Use one local mailbox at a time. Mailpit uses the same SMTP settings; inspect its UI
at `http://127.0.0.1:8025`. Its API differs from the bundled mailbox, so the current
Android E2E harness specifically requires `scripts/mailbox.mjs`.
[Official Mailpit configuration](https://mailpit.axllent.org/docs/install/docker/).

Production SMTP requires `SMTP_HOST`, `SMTP_PORT`, `SMTP_FROM`, `SMTP_USER` and
`SMTP_PASSWORD`. Set `SMTP_SECURE=true` for implicit TLS (usually port 465), or
false for STARTTLS (usually 587); production transport requires TLS and validates
certificates. Local plaintext SMTP is for development only. Provider acceptance is
reported as `SMTP_ACCEPTED`; this does not prove delivery to an external inbox.
No external production email provider or DNS delivery configuration was validated.

Apply additive migration `202610300003_otp_sessions`. Existing pending OTP attempts
lack a verified credential binding and must restart login. OTP/session records contain
only HMAC/hash verification material. See [API](../docs/api-contract.md),
[implementation and sequence](../docs/phase-5-implementation.md) and
[validation](../docs/phase-5-validation.md). No scheduled data-retention cleanup is
implemented yet; deploy explicit retention policies before operating at scale.


## Phase 6 audit tooling

`npm run test:coverage` runs unit and integration suites against the isolated test
DB and writes V8 line/branch coverage. `node scripts/summarize-phase6.mjs` combines
that output with repository-root Flutter LCOV and measured local server-flow samples
into non-secret documentation evidence. `node scripts/audit-pub.mjs` queries OSV
using only public hosted Pub package names/versions from the lockfile; it sends no
application source, credentials or account data. Network failure is not a passing audit.

See [readiness](../docs/production-readiness.md) and [audit](../docs/phase-6-security-audit.md).
The server still lacks remote key attestation. Node software-key fixtures can complete
the signature stage, which must not be described as remote proof of a biometric
prompt. No production deployment is approved by local test or coverage success.
