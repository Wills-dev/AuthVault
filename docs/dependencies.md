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
| dio | ^5.11.1 | Future API data sources/interceptors |
| local_auth | ^3.0.2 | OS capability/prompt support; not server biometric proof |
| flutter_secure_storage | ^11.2.0 | Future platform-protected session storage |
| flutter_lints | ^6.0.0 | Flutter lint baseline |
| mocktail | ^1.0.5 | Future deterministic mocks |
| flutter_test, integration_test | SDK | Widget/unit and on-device test tooling |

Unused starter Cupertino icons were removed. Security/network dependencies are
reserved for subsequent phases and currently make no calls. No secrets are stored.

Backend dependencies will be selected and locked together in Phase 3 rather than
claiming an untested dependency set. Prefer NestJS stable, strict TypeScript,
PostgreSQL, Prisma, Argon2id, JWT tooling, Nodemailer and Jest. Node 24.22.1 is
installed and pinned in .nvmrc. Official requirements checked during planning:
[NestJS](https://docs.nestjs.com/cli/overview),
[Prisma](https://docs.prisma.io/docs/orm/reference/system-requirements).
Mobile package metadata: [Riverpod](https://pub.dev/packages/flutter_riverpod),
[GoRouter](https://pub.dev/packages/go_router), [Dio](https://pub.dev/packages/dio),
[local_auth](https://pub.dev/packages/local_auth),
[secure storage](https://pub.dev/packages/flutter_secure_storage).
