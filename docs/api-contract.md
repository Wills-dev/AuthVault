# Draft API contract — reviewed before Phase 3 integration

No endpoints are implemented yet. Base path `/v1`, JSON over HTTPS. Freeze the DTOs,
exact challenge encoding and status codes during backend implementation before
connecting mobile data sources. All timestamps use UTC ISO 8601.

| Method/path | Input / authorization | Result |
| --- | --- | --- |
| POST /auth/register | fullName, email, password | 201: restricted enrolment attempt and challenge |
| POST /biometric/enrol | enrolment credential, deviceId, publicKey, signature | 201: enrolled; no access tokens |
| POST /auth/login | email, password, deviceId | 200: biometric-stage attempt and challenge |
| POST /biometric/verify | MFA credential, challengeId, signature | 200: OTP stage, expiresAt, resendAt |
| POST /otp/resend | MFA credential | 200: new expiry/cooldown; invalidate previous code |
| POST /otp/verify | MFA credential, six-digit code | 200: accessToken, refreshToken, expiresIn |
| POST /auth/refresh | refreshToken | 200: rotated token pair |
| POST /auth/logout | refreshToken | 204: revoke token family |
| GET /users/me | Bearer access JWT | 200: profile and biometric status |
| GET /users/me/security | Bearer access JWT | 200: completed methods, last login, recent audit activity |

Pending responses include `attemptId`, a separate opaque `attemptToken`, `stage`,
and `expiresAt`. Store only hashed attempt tokens on the server. Supply the
restricted credential through a dedicated `X-MFA-Token` header, never as an access
JWT. Challenge responses include `challengeId`, exact base64url `payload`, and expiry;
the payload binds protocol version, purpose, attempt, device and random nonce.
Do not reconstruct signed JSON on the client. Never return OTP values from an API.

Errors use `{ "error": { "code": "OTP_EXPIRED", "message": "Request a new code.",
"requestId": "..." } }`. Validation may include safe field errors. Proposed codes:
VALIDATION_ERROR (400), INVALID_CREDENTIALS (401), ATTEMPT_EXPIRED (401),
MFA_STAGE_REQUIRED (403), BIOMETRIC_PROOF_INVALID (401), OTP_INVALID (401),
OTP_EXPIRED (401), OTP_CONSUMED (409), RATE_LIMITED (429), SESSION_EXPIRED (401),
INTERNAL_ERROR (500). Rate-limit responses include Retry-After. Avoid account
existence leaks and internal exception details. Reject oversized keys/signatures,
unknown algorithms and malformed input before expensive verification.

Initial policy targets: MFA lifetime 10 minutes; challenges at most 2 minutes and
single use; OTP 5 minutes; resend cooldown 60 seconds; maximum 3 sends and 5 OTP
failures per attempt, followed by 15-minute lockout; access lifetime 5 minutes;
refresh maximum lifetime 7 days. These are proposed policies, not implemented
controls. Apply per-account and per-IP limits and document final limits and
recovery behavior with tests in Phases 3–6.
