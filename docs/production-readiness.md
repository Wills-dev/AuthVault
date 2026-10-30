# Production readiness — Phase 6

**Decision: not production ready.** Debug functionality and unsigned release
compilation do not constitute deployment approval. No deployment or production
credential provisioning was performed. Phase 7 has not started.

## Release gates

| Gate | Current evidence | Required owner/action |
| --- | --- | --- |
| Remote biometric assurance | High AV6-01: exportable software keys accepted by server | Security/backend/native owners: approved attestation and credential migration; physical-device validation |
| Distribution identity/signing | Debug fallback removed; audit release deliberately unsigned; example app ID remains | Mobile owner: owned application ID, signing identity, protected signing pipeline and update/recovery plan |
| API transport | Release cleartext false; explicit HTTPS URL required; local server loopback HTTP | Infrastructure: real TLS ingress, valid owned hostname/certificates, private upstream, renewal/expiry monitoring |
| Database | Three migrations applied locally, no schema drift | Database owner: least privilege, verified production transport/CA, staging migration rehearsal, backups/PITR/restore test |
| SMTP | Production config requires auth and transport TLS; actual tests use loopback SMTP | Messaging owner: approved provider, authenticated TLS, sender domain/SPF/DKIM/DMARC, delivery/bounce monitoring |
| Secrets | Distinct validated 32-byte hex secrets, ignored examples, safe errors | Operator: managed injection, access restrictions, rotation, incident procedures and audit trail |
| Signup/recovery | Address ownership bootstrap and recovery incomplete; signup enumerates | Product/security owner: reviewed generic signup and recovery without key replacement bypass |
| Capacity/retention | Auth quotas and live DB guard; no cleanup scheduler or production capacity test | Backend/operations: bounded ingress/work admission, retention jobs and resource/load budgets |
| Monitoring | Redacted audit records, request IDs and safe 5xx events; no alert pipeline | Operations: authenticated synthetic checks, replay/lockout/5xx/latency alerts, on-call and retention policy |
| Platform support | Android emulator checks; hardware false; iOS runtime/signing unimplemented | Mobile/QA: physical Android matrix, vendor key invalidation, iOS implementation/toolchain and testing |
| Dependency posture | Runtime npm 0 known; Pub OSV 0 matches; six Low dev entries remain | Maintainer: reviewed upstream fix, SBOM/native dependency inventory and recurring audits |

## Environment and transport procedure (proposed, not executed)

1. Provision separate staging/production roles, domains, databases, provider accounts
   and secret-manager entries. Never copy local `.env`/mailbox fixtures to production.
2. Inject the documented NODE_ENV, database, audit/OTP/JWT keys and SMTP settings.
   Each key is independently generated from 32 random bytes. Never log config dumps.
3. Keep NestJS on private/loopback transport behind TLS termination. Restrict direct
   access to the HTTP upstream. The application does not itself provision public
   HTTPS; production `HOST=0.0.0.0` without a restricted TLS ingress is unsafe.
4. Keep Express proxy trust disabled until the exact ingress topology is reviewed.
   Do not trust arbitrary X-Forwarded-For or enable unrestricted `trust proxy=true`:
   rate-limit identity otherwise becomes spoofable.
5. Configure authenticated SMTP: implicit TLS with `SMTP_SECURE=true`, or required
   STARTTLS; default certificate verification must remain enabled. External inbox
   delivery has not been tested. No automatic retry may falsely claim acceptance.
6. Build against an owned HTTPS `API_BASE_URL` ending in `/v1`. The audit build used
   reserved `https://api.authvault.invalid/v1`, which is intentionally not a live API.
   Configure an owned signing key in ignored `android/key.properties`; absence now
   produces an unsigned audit build and never falls back to the debug identity.
7. Validate compiled manifest/resources and signing certificate in CI. The unsigned
   artifact must fail a distribution gate. Do not publish this audit APK.

## Migration, backup and recovery procedure

Use `npm ci`, `npm run generate`, `npm run build`, `npx prisma validate`, then a
reviewed `prisma migrate deploy` in an approved maintenance workflow. Do not run
`migrate reset` or development migrations against production. Phase 6 changes no
schema; the three existing additive migrations remain unmodified. Check status and
drift, and rehearse deployment against a restored staging database first.

Define encrypted backups, key custody, PITR if required, retention, RPO and RTO.
No production recovery-time objective or successful production restore is claimed.
Restore into an isolated environment, verify schema/roles/integrity, and prevent
restored SMTP jobs from emailing users. Revoke sessions/rotate affected secrets
following a reviewed compromise or rollback plan; a stale backup can resurrect
revoked session records unless recovery explicitly addresses that risk.

Cleanup should be bounded and observable. Purge expired rate windows and dead
attempt/challenge records according to an approved retention policy. Keep consumed
refresh-token hashes for the entire active family's lifetime, otherwise reuse
cannot trigger family revocation. Only purge expired/revoked families after the
required replay/audit retention window. Audit/account retention requires explicit
privacy decisions. No destructive cleanup policy was applied during this phase.

## Logging, monitoring and incident response

Retain request IDs, safe status/method events and authentication audit kinds. Never
record passwords, OTPs, pending/access/refresh credentials, signatures or message
bodies. Restrict audit access and avoid treating hashed low-entropy identifiers as
anonymous data if their HMAC secret is exposed. Monitor quota spikes, OTP lockouts,
refresh reuse, datastore failures, SMTP rejection, TLS expiry, cleanup lag and disk
usage. Health liveness alone does not prove authentication, delivery or safety.

JWT signing currently uses one active HS256 key without key IDs. Rotation invalidates
older access JWTs; live refresh can issue new JWTs. OTP-key rotation invalidates
outstanding codes; audit-key rotation changes rate-limit/correlation fingerprints.
Plan coordination and incident behavior instead of assuming transparent rotation.
Database/network loss must fail authorization closed. A lost rotation response can
require new login; retries are intentionally not assumed idempotent.

Current logout reports uncertainty if secure-store deletion or remote revocation
fails. If both fail, persistence on restart cannot be guaranteed absent a durable
logout marker; no misleading success or absolute offline guarantee is claimed.

This checklist is proposed operational work. Findings, executed tests and unresolved
risks are tracked in [audit](phase-6-security-audit.md) and
[validation](phase-6-validation.md), not converted into an approval to deploy.
