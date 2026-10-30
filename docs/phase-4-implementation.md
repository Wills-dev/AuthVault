# Phase 4 implementation notes

Implemented Android Keystore P-256 per-use biometric signing through the narrowly
scoped authvault/biometric_keys MethodChannel: capabilities, create, credential,
sign and cancel. Only public metadata/signatures are returned. Android requires
BIOMETRIC_STRONG and a CryptoObject-bound operation. Login never generates a new
key. No private key, biometric template or authentication boolean is transmitted.

The native implementation uses a worker executor for Keystore operations and the
main executor for prompts/results. Activity background/disposal cancels operations;
stale callbacks cannot return into a newer operation. AndroidX Biometric 1.1.0,
FlutterFragmentActivity, USE_BIOMETRIC permission and AppCompat normal themes are
necessary native changes. Existing SDK/NDK, build types and networking are retained.

BiometricModule adds purpose-bound challenges, canonical SPKI/P-256 parsing,
ECDSA/SHA-256 verification, atomic consumption, stage checks, ownership/status
checks, per-attempt rate limits and audit events. Migration 202610300002 adds
BiometricChallenge/BiometricPurpose and ENROLMENT_COMPLETE without modifying the
Phase 3 migration. No OTP/session implementation was introduced.

Flutter has pure-Dart biometric-key/repository interfaces, a native adapter, Dio
data source/repository, Riverpod operation state and UI actions. Successful enrolment
requires backend confirmation; successful login proof navigates to the existing OTP
screen with PENDING_OTP only. Status reconciliation handles a lost proof response.
Dashboard/profile guards and debug previews remain separate. Password APIs now
include subjectId so a device alias is bound to the authorized account UUID.

See [security design and sequence](biometric-security-design.md),
[API](api-contract.md), and [executed validation](phase-4-validation.md).

Known limitations: iOS secure signing is unsupported/fails closed; no production
attestation verification or physical-device hardware validation; no recovery/device
replacement; no OTP delivery or verification; no completed dashboard session.
Emulator software-backed AndroidKeyStore support is debug-only and is not a fake
cryptographic mode. See the design's honest-client/OS trust assumption.

Suggested commit: `feat: add biometric-protected Android keys and signed MFA challenges`

Phase 5 requires explicit approval and has not started.
