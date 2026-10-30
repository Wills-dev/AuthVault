# API contract — Phase 5

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
| GET /users/me | completed-session Bearer JWT | 200 real account identity |
| GET /users/me/security | completed-session Bearer JWT | 200 account security state |

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
| 401 | SESSION_INVALID | Invalid, expired, revoked or incomplete-MFA authorization |
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

Biometric endpoints do not issue email codes or completed-session tokens; use the
OTP and session endpoints below. There is no separate `/otp/resend` handler:
resending uses `/otp/send` with the same authorization and cooldown checks.

## Phase 5 — OTP and completed session contract (current)

The Phase 3/4 pending-only restrictions above describe historical behavior.
Protected resources now require a completed-session JWT; missing/invalid/pending
Bearer credentials return **401 SESSION_INVALID**, never a successful account response.

| Method/path | Input and authorization | Success |
| --- | --- | --- |
| POST `/otp/send` | `{attemptId: UUIDv4}`, `X-MFA-Token` | 200 `{challengeId, expiresAt, resendAt, delivery: "SMTP_ACCEPTED"}` |
| POST `/otp/verify` | `{attemptId: UUIDv4, challengeId: UUIDv4, code: "six digits"}`, `X-MFA-Token` | 200 session credentials below |
| POST `/auth/refresh` | `{refreshToken: "43-char base64url credential"}` | 200 rotated session credentials |
| POST `/auth/logout` | `{refreshToken: "43-char base64url credential"}` | 204, including unknown credentials |
| GET `/users/me` | `Authorization: Bearer <access JWT>` | 200 `{id, email, fullName, createdAt}` |
| GET `/users/me/security` | same JWT authorization | 200 `{lastAuthentication: ISO timestamp or null, biometricCredentials: number, activeSessions: number, authenticationMethods: string[]}` |

Session response: `{accessToken, refreshToken, accessExpiresAt, sessionExpiresAt}`.
These are credentials: never log them. Access lifetime is five minutes, capped by
the seven-day absolute session deadline. Refresh rotates on every use; consumed
refresh reuse revokes its family. Retrying a lost response can therefore require
new login. No cookies or client-supplied authenticated booleans are used.

OTP request requires a valid PENDING_OTP attempt bound to a server-verified,
non-revoked biometric credential. Only the SMTP-confirmed acceptance path creates
or replaces the challenge. A wrong-stage request returns 403 OTP_UNAVAILABLE;
missing/expired credentials or absent/revoked verified device binding return 401
ATTEMPT_INVALID. Codes are never in API responses, including development mode.
The client shows actual server timestamps; pending-attempt expiry may shorten the
five-minute maximum. Resend defaults to sixty seconds; at most three accepted
sends per attempt. The send endpoint also serves resends.

| Status | Code | Client action |
| --- | --- | --- |
| 400 | OTP_INVALID | Check code; wrong digest consumes one of five guesses |
| 400 | OTP_EXPIRED | Request replacement, subject to cooldown/attempt expiry |
| 400 | OTP_EXHAUSTED | Fifth wrong guess; user locked fifteen minutes |
| 429 | OTP_LOCKED | Wait until user lockout expires; new attempts cannot bypass |
| 429 | OTP_COOLDOWN | Wait for the known `resendAt` deadline |
| 429 | OTP_SEND_LIMIT | Start a new sign-in; accepted-send cap reached |
| 429 | RATE_LIMITED | Apply endpoint/IP backoff; IP guard sets Retry-After |
| 503 | EMAIL_UNAVAILABLE | Provider did not confirm acceptance; retry safely |
| 401 | SESSION_INVALID | Rotate once or clear session and sign in again |

Per-attempt OTP fixed-window quotas: six send requests and fifteen verify requests
per ten minutes, charged only after valid pending-token context. All auth/OTP
requests also share thirty/IP/minute. Consumed/invalidated/cross-attempt challenge
IDs are rejected. Completed-attempt OTP replay returns ATTEMPT_INVALID. Malformed
DTOs and unknown fields return 400 VALIDATION_ERROR.

Protected endpoints verify signature, fixed issuer/audience/type/required claims,
access expiry, live session ownership/expiry/revocation and active credential ownership.
Logout/replay revokes the database session, so later requests using its unexpired
JWT also fail. In-flight requests already authorized may finish. No endpoint accepts
a pending credential as full authorization; `/preview/*` are client debug routes,
not backend endpoints.
