# Navigation — Phase 2

All routes live in `lib/app/router/app_router.dart` and use a Riverpod-owned
GoRouter disposed with its provider scope.

| Path | Screen / behavior |
| --- | --- |
| `/` | Welcome; login, registration, debug gallery entry |
| `/login` | Validated email/password form; registration and explanation links |
| `/register` | Name/email/passphrase/confirmation; return to login |
| `/biometric` | Actual device capability query; no biometric proof or enrolment |
| `/otp` | Email-code explanation/input; no issued code or access grant |
| `/dashboard` | Always redirects to login in Phase 2 |
| `/profile` | Always redirects to login in Phase 2 |
| `/preview` | Debug-only screen gallery |
| `/preview/dashboard` | Debug-only placeholder dashboard |
| `/preview/profile` | Debug-only placeholder account/security layout |

Welcome → login or registration. Login’s “How device verification works” link →
biometric explanation → “About email verification” → OTP explanation. These links
are informational, not successful authentication transitions. Submitting any form
cannot advance MFA or create tokens. Recovery is marked coming soon and explains
its unavailability when selected. Back uses the router stack, falling back to welcome
when a screen was opened directly.

The gallery link and its routes are registered only inside `kDebugMode` branches.
A second redirect rejects preview paths when not debugging. Profile/release builds
therefore have no preview routes. No environment toggle or client session flag can
enable previews. Unknown routes show the welcome screen. Tests exercise both route
policy branches; a release binary has not been built or tested in Phase 2.

Dashboard → profile stays within `/preview`; “Log out · Exit preview” returns to
welcome. This is a preview exit, not server token revocation. There are no sessions,
tokens, protected requests or backend authorization decisions in this phase. Future
backend guards remain mandatory regardless of navigation behavior.

Login and registration have separate widget identities and separate auto-disposed
submission providers; OTP owns its own provider too. Going back through the normal
stack preserves the form while mounted; replacing a credential route does not reuse
password input in the other form. Scrollable shells use screen-specific identity.

## Phase 3 update

Login and registration submit through the real repository. A successful backend
response moves to /biometric with only an in-memory pending attempt. Registration
shows enrolment required; login shows biometric and email verification required.
The pending-status endpoint confirms the attempt. Cancel clears/revokes the attempt
and returns to login. OTP remains informational/unavailable. Both normal protected
routes still always redirect to login, including when password authentication has
succeeded. Debug previews remain isolated and create no completed session.

## Phase 4 update

/biometric now exposes Enrol device biometrics only for PENDING_ENROLMENT and
Verify with biometrics only for PENDING_BIOMETRIC. Enrolment confirmation offers
Return to login; login proof success navigates to /otp with PENDING_OTP. Status
reconciliation can expose Continue to email verification after an uncertain network
response. No OTP is issued or verified. Protected routes and preview gates remain
unchanged, regardless of biometric success.

## Phase 5 update (current behavior)

`/otp` uses the real OTP repository when an in-memory PENDING_OTP attempt exists.
Send/resend requires confirmed biometric proof on the server. Code verification
saves refresh credentials securely before creating local session state and routing
to `/dashboard`. Wrong/expired/exhausted/network outcomes never create a session.
`/dashboard` and `/profile` now render real backend account/security data only for
a completed session. They redirect to login when signed out.

`/restore` gates startup while saved credentials are rotated. Failed restoration
keeps account routes gated and offers explicit retry/local sign-out. An invalid or
expired saved credential is cleared. JWT expiry triggers serialized refresh when
requesting account data; rejected refresh clears the session and redirects. Logout
clears local storage and revokes the server session; offline revocation uncertainty
is stated explicitly. A pending token or preview entry cannot unlock these routes.

Debug `/preview`, `/preview/dashboard` and `/preview/profile` retain placeholder-only
pages, labels and navigation. They do not change session state or bypass API guards.
Release/profile builds omit preview routes. The router remains stable while a
Riverpod session listener refreshes redirect decisions; it is not recreated on each
state change. App restart discards unfinished MFA and typed codes.


## Phase 6 lifecycle hardening

Logout ends local access immediately before awaited storage/network work. Cleanup or
server-revocation failure is explicitly reported. Delayed restoration and stale
invalid-session cleanup cannot overwrite a newer session. Backend authorization
remains mandatory regardless of client state or debug route visibility.
