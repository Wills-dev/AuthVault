# API contract — Phase 3

Base path `/v1`. JSON, UTC ISO-8601 timestamps, no cookies. Remote APIs require
HTTPS. Local debug Android uses `http://10.0.2.2:3000/v1` only.

## Implemented endpoints

| Method/path | Input / authorization | Successful result |
| --- | --- | --- |
| POST /auth/register | fullName, email, password | 201: pending enrolment attempt |
| POST /auth/login | email, password | 200: pending biometric attempt |
| GET /auth/pending/:id | X-MFA-Token | 200: attemptId, stage, expiresAt |
| DELETE /auth/pending/:id | X-MFA-Token | 204: revoke pending attempt |
| GET /health/live | none | 200: status ok |
| GET /health/ready | none | 200: status ok, database reachable; queries PostgreSQL |
| GET /users/me | no completed-session mechanism yet | Always 403 MFA_REQUIRED |
| GET /users/me/security | no completed-session mechanism yet | Always 403 MFA_REQUIRED |

Registration and password-login responses contain **only** `attemptId` (UUID),
`attemptToken` (32 cryptographically random bytes, base64url), `stage` and `expiresAt`.
Registration uses PENDING_ENROLMENT; login uses PENDING_BIOMETRIC. No access token,
refresh token, user password/hash or biometric challenge is returned. Status omits
the secret token. A pending credential is not accepted as Bearer authorization.

Email is trimmed/lowercased, validated and capped at 254 characters. Full name is
trimmed and must be 2–100 characters. Registration passwords must be 12–128
characters with at least one non-whitespace character. Passwords are not trimmed.
Login accepts 1–128 characters to avoid leaking password policy through login.
Unknown fields are rejected. JSON bodies are limited to 8 KiB. Confirmation is
client-side only and is not sent to the API. deviceId belongs to Phase 4 and is
not accepted by Phase 3 DTOs.

Attempts expire after 600 seconds by default (startup configuration permits
60–900 seconds). Only non-expired enrolment/biometric pending attempts can be
queried or cancelled with a matching token. Invalid IDs/DTOs return 400; invalid,
missing, expired or revoked pending credentials return 401 ATTEMPT_INVALID.

## Errors and limits

Errors use `{ "error": { "code": "INVALID_CREDENTIALS", "message": "Email or
password is incorrect.", "requestId": "server-generated UUID" } }`.

| Status | Code | Meaning |
| --- | --- | --- |
| 400 | VALIDATION_ERROR | Invalid DTO/JSON; no submitted values echoed |
| 400 | REGISTRATION_UNAVAILABLE | Account cannot be created; no email-specific detail |
| 401 | INVALID_CREDENTIALS | Same message for unknown email and wrong password |
| 401 | ATTEMPT_INVALID | Missing, invalid, revoked or expired attempt credential |
| 403 | MFA_REQUIRED | Protected resources reject all Phase 3 credentials |
| 413 | PAYLOAD_TOO_LARGE | Request exceeds body limit |
| 429 | RATE_LIMITED | Retry-After header states seconds to wait |
| 503 | SERVICE_UNAVAILABLE | Database/service unavailable; fail closed |
| 500 | INTERNAL_ERROR | Unexpected failure; no internal details |

PostgreSQL atomic counters enforce fixed windows: 30 auth requests/IP/minute and
10 credential submissions/normalized email/15 minutes. Status/revocation consume
IP quota only. Counters are shared by instances using the same database and
AUDIT_HMAC_KEY; identities are HMACed, not stored as plain emails/IPs in counters.
No proxy headers are trusted; production proxy deployments need an explicit,
reviewed client-IP strategy. Fixed windows allow boundary bursts. Expired counter
rows require periodic retention cleanup; this prototype does not run a scheduler.

Responses include Cache-Control: no-store and server-generated X-Request-Id.
CORS is not enabled; native Flutter does not require it. Health routes are for
local readiness and liveness; restrict their exposure when deploying.

## Reserved — not implemented

Biometric enrolment/signature verification, OTP issue/resend/verification, completed
access sessions, refresh rotation and logout remain future work. The previous
Phase 1 challenge contract was a draft: Phase 3 returns no challenge and cannot
complete MFA. Phase 4 must specify device-bound challenge encoding and key proof
before adding those endpoints. Future token issuance must require every stage.

| Reserved path | Planned phase / boundary |
| --- | --- |
| POST /biometric/enrol | Phase 4: restricted enrolment proof of possession |
| POST /biometric/verify | Phase 4: signed server challenge, no client boolean proof |
| POST /otp/resend | Phase 5: rate-limited delivery bound to a valid attempt |
| POST /otp/verify | Phase 5: single-use expiring code; completed access only after all stages |
| POST /auth/refresh | Phase 6: rotate hashed refresh records and detect reuse |
| POST /auth/logout | Phase 6: revoke completed-session refresh family |

These reserved paths have no Phase 3 handlers and return not-found responses.
Their DTOs and challenge/signature encoding must be finalized before implementation.
