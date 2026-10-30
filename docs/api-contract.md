# API contract — Phase 4

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

Registration and password-login responses contain `subjectId` (authorized account UUID), `attemptId` (UUID),
`attemptToken` (32 cryptographically random bytes, base64url), `stage` and `expiresAt`.
Registration uses PENDING_ENROLMENT; login uses PENDING_BIOMETRIC. No access token,
refresh token, user password/hash or biometric challenge is returned. Status omits
the secret token. A pending credential is not accepted as Bearer authorization.

Email is trimmed/lowercased, validated and capped at 254 characters. Full name is
trimmed and must be 2–100 characters. Registration passwords must be 12–128
characters with at least one non-whitespace character. Passwords are not trimmed.
Login accepts 1–128 characters to avoid leaking password policy through login.
Unknown fields are rejected. JSON bodies are limited to 8 KiB. Confirmation is
client-side only and is not sent to the API. Credential UUIDs are supplied only
to biometric DTOs; password DTOs do not accept deviceId or client MFA-stage flags.

Attempts expire after 600 seconds by default (startup configuration permits
60–900 seconds). Only non-expired restricted enrolment, enrolment-complete, biometric and OTP attempts can be
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
| 403 | MFA_REQUIRED | Protected resources reject all incomplete-MFA credentials |
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

## Biometric contract

Registration/login/status now also return subjectId, the authorized account UUID.
Pending status supports PENDING_ENROLMENT, ENROLMENT_COMPLETE, PENDING_BIOMETRIC
and PENDING_OTP. No accessToken or refreshToken is added. Enrolment completion
requires a new password login before the login-specific biometric step.

All three implemented biometric endpoints require X-MFA-Token, existing auth IP
limits, validated JSON and a server-valid purpose-specific pending context.

| Method/path | Request JSON | Result |
| --- | --- | --- |
| POST /biometric/challenge | attemptId, credentialId (v4 UUID), purpose ENROLMENT or LOGIN, publicKey | 200: challengeId, payload, purpose, credentialId, subjectId, attemptId, expiresAt, algorithm ES256_DER |
| POST /biometric/enrol | attemptId, credentialId, challengeId, signature | 200: same attempt/subject/credential IDs, stage ENROLMENT_COMPLETE, expiresAt |
| POST /biometric/verify | attemptId, credentialId, challengeId, signature | 200: same IDs, stage PENDING_OTP, expiresAt |

publicKey is standard base64 SPKI DER for enrolment and must be the empty string
for LOGIN (which uses the registered key). signature is standard base64 DER ECDSA,
not P1363. payload is unpadded base64url; sign its decoded bytes exactly with
SHA256withECDSA. Protocol/context encoding is specified in biometric-security-design.md.

Challenges expire within two minutes, are bounded by attempt expiry and have one
successful use. New issuance invalidates earlier challenges for the same attempt.
Five issuances and five proof submissions/attempt/ten-minute fixed window are
allowed after pending authorization. Generic 401 BIOMETRIC_REJECTED covers bad
stage, ownership, key status, purpose, expiry, replay and signature. Existing 400
validation, 429 rate limiting and safe service-error envelopes remain. No credential
lookup/replacement/recovery or password-only revocation endpoint is exposed.

OTP, refresh and completed-session endpoints remain reserved/unimplemented.

## Reserved — not implemented

POST /otp/resend and POST /otp/verify belong to Phase 5. POST /auth/refresh and
POST /auth/logout belong to Phase 6. They have no handlers and return not found.
No email code or completed-session token is issued by the biometric endpoints.
