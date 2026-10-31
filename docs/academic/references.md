# References

A provisional numbered style is used throughout this package. Confirm the institution's required citation style before export. Primary publisher/maintainer pages were checked on **30 October 2026**. Living documentation is cited by organization and access date rather than an invented publication year. These sources explain concepts; project measurements come from the separate repository evidence listed below.

<a id="ref-1"></a>
[1] J. Bonneau, C. Herley, P. C. van Oorschot, and F. Stajano, *The quest to replace passwords: a framework for comparative evaluation of Web authentication schemes*, University of Cambridge Computer Laboratory, Technical Report UCAM-CL-TR-817, March 2012. DOI: [10.48456/tr-817](https://doi.org/10.48456/tr-817). [Publisher record and full-text link](https://www.cl.cam.ac.uk/techreports/UCAM-CL-TR-817.html). The extended technical report is cited here, not an invented journal version.

<a id="ref-2"></a>
[2] National Institute of Standards and Technology, *Digital Identity Guidelines: Authentication and Authenticator Management*, NIST SP 800-63B-4, July 2025. [Publication record](https://csrc.nist.gov/pubs/sp/800/63/b/4/final); [authenticator requirements, especially §§3.1.3 and 3.2.3](https://pages.nist.gov/800-63-4/sp800-63b/authenticators/). Used to distinguish assurance requirements from prototype claims, including restrictions on email authentication. This is revision 4, not the superseded revision 3.

<a id="ref-3"></a>
[3] A. Biryukov, D. Dinu, D. Khovratovich, and S. Josefsson, *Argon2 Memory-Hard Function for Password Hashing and Proof-of-Work Applications*, RFC 9106, September 2021. [RFC Editor](https://www.rfc-editor.org/rfc/rfc9106.html). An informational IRTF/CFRG document supporting the password-hashing discussion.

<a id="ref-4"></a>
[4] OWASP Foundation, *Password Storage Cheat Sheet*, living documentation, accessed 30 October 2026. [Official cheat sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html). Used for salted, adaptive password storage and Argon2id guidance; not proof of project compliance.

<a id="ref-5"></a>
[5] Google, Android Developers, *Android Keystore system*, living documentation, accessed 30 October 2026. [Official documentation](https://developer.android.com/privacy-and-security/keystore). Explains device key protection and the distinction between software and hardware enforcement.

<a id="ref-6"></a>
[6] Google, Android Developers, *Show a biometric authentication dialog*, living documentation, accessed 30 October 2026. [Official documentation](https://developer.android.com/identity/sign-in/biometric-auth). Supports the BiometricPrompt/CryptoObject implementation discussion.

<a id="ref-7"></a>
[7] Google, Android Developers, *Verify hardware-backed key pairs with key attestation*, living documentation, accessed 30 October 2026. [Official documentation](https://developer.android.com/privacy-and-security/security-key-attestation). Explains why a valid signature alone does not establish remote hardware provenance.

<a id="ref-8"></a>
[8] D. M'Raihi, M. Bellare, F. Hoornaert, D. Naccache, and O. Ranen, *HOTP: An HMAC-Based One-Time Password Algorithm*, RFC 4226, December 2005. [RFC Editor](https://www.rfc-editor.org/rfc/rfc4226.html). Counter-based comparison only; AuthVault does not implement HOTP.

<a id="ref-9"></a>
[9] D. M'Raihi, S. Machani, M. Pei, and J. Rydell, *TOTP: Time-Based One-Time Password Algorithm*, RFC 6238, May 2011. [RFC Editor](https://www.rfc-editor.org/rfc/rfc6238.html). Time-based comparison only; AuthVault does not implement TOTP.

<a id="ref-10"></a>
[10] M. Jones, J. Bradley, and N. Sakimura, *JSON Web Token (JWT)*, RFC 7519, May 2015. [RFC Editor](https://www.rfc-editor.org/rfc/rfc7519.html). Defines the claims/token format, not a complete authentication system.

<a id="ref-11"></a>
[11] Y. Sheffer, D. Hardt, and M. Jones, *JSON Web Token Best Current Practices*, RFC 8725 / BCP 225, February 2020. [RFC Editor](https://www.rfc-editor.org/rfc/rfc8725.html). Used for explicit algorithm, issuer, audience and token-context validation.

<a id="ref-12"></a>
[12] T. Lodderstedt, J. Bradley, A. Labunets, and D. Fett, *Best Current Practice for OAuth 2.0 Security*, RFC 9700 / BCP 240, January 2025. [RFC Editor](https://www.rfc-editor.org/rfc/rfc9700.html), §4.14. Used as a comparison for refresh replay detection and rotation; AuthVault is not an OAuth 2.0 or OpenID Connect implementation.

<a id="ref-13"></a>
[13] OWASP Foundation, *Mobile Application Security Verification Standard (MASVS)*, living documentation, accessed 30 October 2026. [Official standard](https://mas.owasp.org/MASVS/). Provides mobile storage, cryptography, authentication and network assessment categories. No MASVS certification or exhaustive assessment is claimed.

<a id="ref-14"></a>
[14] Flutter team, *Guide to app architecture*, living documentation, accessed 30 October 2026. [Official guide](https://docs.flutter.dev/app-architecture/guide). Supports separation of views, state and repositories; the project's Riverpod/feature-first implementation is its own adaptation.

<a id="ref-15"></a>
[15] NestJS, *Modules*, living documentation, accessed 30 October 2026. [Official guide](https://docs.nestjs.com/modules). Supports modular dependency organization; it is not experimental evidence of framework superiority.

<a id="ref-16"></a>
[16] PostgreSQL Global Development Group, *PostgreSQL 17 Documentation: 13.3 Explicit Locking*. [Version 17 documentation](https://www.postgresql.org/docs/17/explicit-locking.html), accessed 30 October 2026. Used for row-lock concurrency reasoning matching the project's PostgreSQL major version.

<a id="ref-17"></a>
[17] Nodemailer, *SMTP transport*, living documentation, accessed 30 October 2026. [Official documentation](https://nodemailer.com/smtp). Describes transport configuration; SMTP acceptance does not establish external inbox delivery.

## Project evidence and source hierarchy

These are primary project artifacts, not external research publications. Relative links target the submitted repository. Historical Phase 1–5 documents describe their respective stages; current source and Phase 6 validation govern final implementation claims. Statements in historical documents that later phases have not started retain their original historical meaning.

| Evidence ID | Artifact | Use |
| --- | --- | --- |
| E1 | [Phase 6 validation](../phase-6-validation.md) | Executed checks, failures, final successful retest and build scope |
| E2 | [Coverage JSON](../evidence/phase-6/coverage-summary.json), [coverage analysis](../test-coverage.md) | Numerators, denominators, exclusions |
| E3 | [Native evidence](../evidence/phase-6/native-evidence.json) | Manual sensor run, software-backed report, restoration scope |
| E4 | [Performance summary](../evidence/phase-6/performance-summary.json), [raw measurements](../evidence/phase-6/performance.json) | Five local scenarios; instrumentation limitations |
| E5 | [Security audit](../phase-6-security-audit.md), [threat model](../threat-model.md) | Findings, residual risks and remediation status |
| E6 | [Android artifact inspection](../evidence/phase-6/android-artifacts.json) | Unsigned release and manifest assertions |
| E7 | [npm audit summary](../evidence/phase-6/npm-audit-summary.json), [Pub audit](../evidence/phase-6/pub-audit.json) | Dated dependency snapshots |
| E8 | [API contract](../api-contract.md), [Prisma schema](../../backend/prisma/schema.prisma) | Protocol and actual database relations |
| E9 | [Phase 1](../phase-1-validation.md), [Phase 2](../phase-2-validation.md), [Phase 3](../phase-3-validation.md), [Phase 4](../phase-4-validation.md), [Phase 5](../phase-5-validation.md) | Development history, not additional final-suite counts |

No participant study, independent penetration test, formal protocol proof, hardware certification or production deployment is supplied by these artifacts.
