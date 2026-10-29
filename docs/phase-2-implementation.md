# Phase 2 — authentication UI and navigation

## Implemented

Seven screens: welcome, login, registration, biometric readiness, email OTP,
dashboard preview, and profile/security preview. A separate debug-only gallery
makes previews discoverable without simulating sign-in.

The UI retains the existing Material 3 navy/teal theme, safe-area scrollable shell,
48-pixel button targets and system text scaling. Shared page headers, notices,
action buttons and cards are in `core/widgets/VaultComponents`. Reusable fields
handle labels, visibility, keyboard actions, focus traversal, email hints and error
layout. Controllers are disposed. The welcome fade is short and disabled by the
system reduced-motion setting. Other transitions use the Material router defaults.

Feature-first folders separate credential validation from presentation. A core
biometric service owns local_auth platform queries; providers coordinate async
capability and submission states. Widgets make no HTTP requests. No Android Gradle,
manifest or native activity changes were necessary. No dependencies were added.

## Honest state boundaries

- Login/registration validate locally, then the unavailable action throws an
  explicit unavailable error. No credentials are sent, logged or persisted.
- Async UI supports per-button loading and prevents duplicate submission. Real
  unavailable actions finish immediately; tests hold a Future to exercise loading.
- Biometric checks use `isDeviceSupported`, `canCheckBiometrics` and enrolled
  modalities. Ready, unavailable, not enrolled, cancellation, lockout and failure
  presentations exist. Readiness success is explicitly not identity verification.
  No native authentication prompt is invoked before secure key/challenge support.
- OTP is one accessible six-digit field: numeric keyboard, digit filtering, length
  cap, standard paste, one-time-code autofill, Next/Done keyboard behavior and
  localized validation. Invalid/expired response presentations and expiry/cooldown
  helpers are tested with fixtures. No codes or server responses are fabricated.
- Timing accepts future server expiry/resend timestamps and updates through an
  auto-disposed clock stream. Without an issued code, no countdown is invented and
  resend remains unavailable. Server-side policy will be implemented later.
- The protected dashboard/profile routes always fail closed. Only debug gallery
  paths render their layouts, with explicit preview notices and placeholder values.
  No authentication success state or session exists in this phase.

See [navigation](navigation.md) and [validation](phase-2-validation.md).

## Known limitations and next phase

No backend, email delivery, real MFA session, native biometric signing, recovery,
profile editing or logout revocation is implemented. Biometric readiness mocks
prove only UI presentation; the Android emulator reported unavailable. Physical
Android/iOS biometrics and assistive-technology device testing remain outstanding.
Full Xcode/CocoaPods are still missing; no iOS build was performed. Debug startup
frame warnings are not performance evaluation results. No release binary was built.

Phase 3 (NestJS/PostgreSQL registration and password login) requires approval.
Suggested commit: `feat: add authentication UI and guarded development previews`.
