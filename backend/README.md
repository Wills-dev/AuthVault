# AuthVault backend — Phase 3

NestJS 12.3.2, strict TypeScript, PostgreSQL and Prisma 7.10.1. The only authentication
result is an expiring pending-MFA credential. No access or refresh tokens are issued.

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
policies. Phase 4 is not implemented and requires approval.
