# Dependency decisions

Resolved against the installed Flutter stable 3.47.9 / Dart 3.13.7 SDK on
29 October 2026. pubspec.yaml declares compatible ranges; commit pubspec.lock for
reproducibility. Pub resolution checks SDK/package compatibility; analysis/tests
check the code used here. Native plugin readiness still needs platform builds and
physical-device testing. Do not upgrade dependencies without repeating checks.

| Dependency | Selected constraint | Purpose |
| --- | --- | --- |
| flutter_riverpod | ^3.4.3 | State/DI; explicit providers, no generator |
| go_router | ^18.1.2 | Central declarative navigation |
| dio | ^5.11.1 | API data sources and authenticated requests |
| local_auth | ^3.0.2 | OS capability/prompt support; not server biometric proof |
| flutter_secure_storage | ^11.2.0 | Platform-protected refresh credential storage |
| flutter_lints | ^6.0.0 | Flutter lint baseline |
| mocktail | ^1.0.5 | Future deterministic mocks |
| flutter_test, integration_test | SDK | Widget/unit and on-device test tooling |

Unused starter Cupertino icons were removed. Security/network dependencies now serve real backend, native biometric and session
flows. Only refresh credentials persist using platform secure storage.

Backend dependencies are now selected and locked in backend/package.json and
package-lock.json: NestJS 12.3.2, Config 12.0.1, Prisma/client/adapter-pg 7.10.1,
Argon2 0.45.1, pg 8.23.1, Helmet 8.3.0, class-validator 0.15.1,
class-transformer 0.5.1, TypeScript 5.9.3, Jest 30.5.2 and ts-jest 29.4.15.
They were verified together with strict compilation and executed tests. Phase 5 adds Nodemailer 10.3.1 and jose 6.2.14 for SMTP and JWT operations,
with smtp-server 3.21.3 and its typings restricted to development/test tooling. Node 24.22.1 remains pinned in .nvmrc.
[Official NestJS requirements](https://docs.nestjs.com/cli/overview) and
[Prisma requirements](https://docs.prisma.io/docs/orm/reference/system-requirements)
were checked during selection. Runtime dependency audit results are recorded in
Phase 3 validation; an audit is a snapshot rather than a security guarantee.


Phase 5 uses Nodemailer with SMTP logging disabled and bounded timeouts. JWT signing
and verification use explicit HS256, issuer, audience, type, required claims and
expiry policy. Package/lock files pin backend resolutions. The bundled local mailbox
requires dev dependencies; the production service imports only Nodemailer.
[SMTP transport](https://nodemailer.com/smtp),
[jose](https://github.com/panva/jose).
