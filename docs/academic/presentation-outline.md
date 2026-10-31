# Defense presentation outline

**15 proposed slides**, approximately 12–15 minutes plus questions. This is an outline with speaker notes, not an exported slide deck or an institution-approved timing requirement. Use concise slide text and explain details orally. Add the final author, programme, supervisor, institution and submission date only after confirmation. Citations below link to the [reference list](references.md); measured results link to project evidence.

## Slide 1 — Title

- AuthVault: Android authentication prototype
- Password → native-authorized signature → email code
- [Author / student ID / institution / supervisor / date]

**Speaker notes:** Introduce the academic scope. Say “prototype,” not production-ready. Identify your own contribution accurately and meet institutional authorship/disclosure rules.

## Slide 2 — Background

- Password compromise can defeat password-only access.
- Added checks create security, usability and deployment tradeoffs.
- Authentication must include enrollment and session lifecycle.

**Speaker notes:** Explain the motivation using the comparative framework, not a fabricated breach statistic. Cite [Bonneau et al., 2012](references.md#ref-1).

## Slide 3 — Problem statement

- Multiple screens do not establish server authorization.
- Replay, races and token reuse can bypass intended sequencing.
- Local biometric success does not prove remote key provenance.

**Speaker notes:** State the concrete design problem: pending verification must remain separate from an authenticated session. The provenance distinction is a research finding, not a minor footnote.

## Slide 4 — Aim, objectives and questions

- Implement an ordered, backend-enforced Android flow.
- Integrate native signing, delivered codes and revocable sessions.
- Evaluate correctness, local performance and residual risk.

**Speaker notes:** Summarize RQ1–RQ4 from Chapter 1. Note that strong remote biometric assurance is only partially achieved.

## Slide 5 — Proposed solution and scope

- Flutter Material 3, Riverpod and GoRouter
- NestJS, Prisma/PostgreSQL, Android Keystore and SMTP
- Android/local evaluation; isolated debug UI previews

**Speaker notes:** Explain why these tools support modularity and testability. Do not claim a comparative framework performance advantage. iOS and production deployment are outside validated scope.

## Slide 6 — Architecture and trust boundaries

- Client: UI/state, secure storage and native key bridge
- Backend: authoritative MFA/session checks
- Database and external mail transport

**Visual:** [Architecture diagram 1](architecture-diagrams.md#1-high-level-system-architecture).

**Speaker notes:** Follow a request across the diagram. Public keys/signatures cross the boundary; raw biometric templates/private keys do not. Cite [Android Keystore](references.md#ref-5).

## Slide 7 — Authentication workflow

- Registration/enrolment returns to login without a session.
- Password → signed login proof → pending OTP
- Only committed code verification issues credentials.

**Visual:** [Sequence diagram 2](architecture-diagrams.md#2-authentication-sequence).

**Speaker notes:** Explain why `X-MFA-Token` is not Bearer authorization. Demonstrate that state is not controlled by a client field.

## Slide 8 — Implementation highlights

- Feature-first UI and module-based backend
- Context-bound, single-use biometric challenges
- HMAC-protected random email codes and atomic completion

**Visual:** Select [OTP or dashboard capture](project-report.md#47-interface-and-selected-screenshots).

**Speaker notes:** Identify source locations without reading long code. The emailed code is neither HOTP nor TOTP; code screenshots contain no OTP value.

## Slide 9 — Security and session design

- Argon2id password hashes; bounded verification requests
- Live-session/credential checks behind short JWTs
- Refresh rotation, replay family revocation and logout

**Visual:** [Session lifecycle diagram 6](architecture-diagrams.md#6-session-lifecycle).

**Speaker notes:** Explain the tradeoff of a database check and strict replay handling. Reference [JWT BCP](references.md#ref-11) and [refresh comparison](references.md#ref-12); do not call the app OAuth/OIDC.

## Slide 10 — Live demonstration

- Register and authorize native enrolment.
- Login, authorize proof, receive and verify real fixture code.
- Show account/profile, restoration, logout and denial.

**Speaker notes:** Follow the [demo guide](demonstration-guide.md). The user touches the enrolled emulator sensor twice. No PIN, password, token or mailbox-wide code list should be projected. If the live environment fails, disclose it and use dated Phase 6 evidence; do not simulate success.

## Slide 11 — Test results

- **87** Flutter tests passed.
- **69** backend tests passed: 21 unit + 48 integration.
- Backend lines **99.45%**, branches **83.74%**; Flutter lines **76.84%**.

**Speaker notes:** Cite [Phase 6 validation](../phase-6-validation.md) and [coverage evidence](../evidence/phase-6/coverage-summary.json). These are recorded results, not a fresh presentation run. Native coverage and Flutter branch coverage are not supplied; line coverage is not security proof.

## Slide 12 — Performance and native evaluation

- Manual native MFA scenario: **29 s**, excluding build/install.
- Local server-flow median: **390.90 ms**, **n=5**.
- Human/native time excluded from server experiment.

**Speaker notes:** Show the [timing table](testing-and-evaluation.md#6-performance-measurements). Describe local HTTP/PostgreSQL/SMTP, Jest instrumentation and software EC fixtures. Do not combine the two timings or call them production benchmarks or human usability averages.

## Slide 13 — Limitations and security findings

- No server-side attestation; emulator hardware backing **false**.
- Signup enumeration and recorded Low dev-tool advisory remain.
- No physical Android/iOS, external email or operational validation.

**Speaker notes:** The server accepts software-key proofs, a confirmed High assurance gap. NIST excludes email as out-of-band authentication, so no AAL/phishing-resistance claim is made ([source](references.md#ref-2)). No participant study or independent pentest occurred. Release compilation was unsigned, not production distribution.

## Slide 14 — Conclusion and recommendations

- Functional, inspectable integration within tested scope
- Stronger assurance requires provenance and lifecycle controls.
- Priorities: attestation/policy, recovery, devices and operations

**Speaker notes:** Answer the research questions in one sentence each. Separate implemented safeguards from proposed future work. No additional development phase has started.

## Slide 15 — Evidence, references and questions

- [Report and references](project-report.md)
- [Evaluation](testing-and-evaluation.md) and [seven diagrams](architecture-diagrams.md)
- [Defense questions](defense-questions.md) and [submission checklist](submission-checklist.md)

**Speaker notes:** Keep the repository evidence index available for questions. Acknowledge uncertainty precisely. Use “not measured” where appropriate rather than offering invented results.

## Export/rehearsal checklist

Render Mermaid views with a trusted local tool and check readability at presentation size. Include image captions and sources; retain aspect ratios and avoid cropping away error/preview labels. Replace institutional placeholders and add full bibliographic entries in notes/handout according to the required style. Rehearse with a private local mailbox and prearranged enrolled sensor input. Slide rendering, timed rehearsal and institutional approval remain submission tasks, not completed measurements.
