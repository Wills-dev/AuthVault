# Academic submission checklist

Prepared 30 October 2026. Checked items describe this documentation package and verified repository evidence, not institutional approval or new application execution. No institution-specific rubric/template was found. Unchecked items require the student's/institution's action or separate validation.

## Package and technical accuracy

- [x] Six-chapter [report](project-report.md), abstract and objective/research-question assessment prepared.
- [x] [References](references.md) use verified publisher/maintainer sources and a consistent provisional numeric style.
- [x] [Seven architecture diagrams](architecture-diagrams.md) cover architecture, sequence, biometric, OTP, database, session and navigation.
- [x] [Evaluation](testing-and-evaluation.md) separates recorded results, expected behavior and unmeasured properties.
- [x] [Defense guide](defense-questions.md) contains 38 substantive questions with answers.
- [x] [Presentation outline](presentation-outline.md) contains 15 slides with speaker notes.
- [x] [Demonstration guide](demonstration-guide.md) covers backend/database, emulator, enrolment, login, OTP, protected account, restoration, logout and denial.
- [x] Root [README](../../README.md) links to the academic package.
- [x] Test/coverage/timing values checked against Phase 6 evidence, with exclusions and experimental boundaries disclosed.
- [x] Diagram relationships checked against source/schema, including UUID scalars that are not foreign keys.
- [x] All seven blocks passed Mermaid 11.12.0 syntax parsing in a temporary Node/DOM environment; no application dependencies changed.
- [x] Local documentation links/anchors and Markdown fence balance checked; `git diff --check` passed.
- [x] Existing Phase 1–6 documentation, evidence and screenshots preserved.
- [x] No application features or further development phase introduced.

## Institutional details to confirm

- [ ] Confirm approved project title; replace author name, student ID, institution, faculty/department, programme/degree, supervisor and submission date.
- [ ] Obtain the actual handbook/template/rubric, submission deadline, permitted file formats and required number of copies.
- [ ] Confirm chapter/word limits, abstract length, paper size, margins, font/size, line spacing and heading numbering.
- [ ] Confirm citation style; convert the provisional numbered references consistently if required.
- [ ] Add only genuine required title/approval/declaration/dedication/acknowledgement pages; do not invent signatures or approval dates.
- [ ] Confirm required lists of contents/figures/tables, abbreviation list, Roman/Arabic pagination and appendix conventions.
- [ ] Confirm ethics/participant-study requirements. No participants or ethics approval are claimed; do not invent either. Seek approval before any future participant research.
- [ ] Confirm authorship, code attribution, permitted AI-assistance disclosure, originality and similarity-check rules; complete them honestly.
- [ ] Confirm source-code/software license and screenshot rights/attribution requirements for submission or public sharing.
- [ ] Obtain supervisor review and any required signed departmental approval separately.

## Export and defense preparation

- [ ] Export the manuscript to required PDF/DOCX format; verify fonts, page breaks, cross-references, tables and image resolution.
- [ ] Render Mermaid diagrams in the final export and inspect text size, line routing and relationship labels. Markdown sources alone are not an exported manuscript.
- [ ] Create the actual slide deck from the outline; include full references in notes/handout if required.
- [ ] Replace placeholders and ensure title/author/date match across report, slides and forms.
- [ ] Rehearse within the institution's allotted time and prepare answers using the source/evidence index.
- [ ] Rehearse the live environment, native sensor input and private code retrieval; retain new results separately from historical evidence.
- [ ] If showing OS process-restart restoration, execute and record that additional rehearsal. Existing native evidence proves provider-container restoration only.
- [ ] Prepare an honest fallback using dated evidence; label live failures rather than simulate a successful login.
- [ ] Inspect the final submission archive for secrets: exclude ignored `.env`, `.local`, database dumps, private keys, PIN/password files, OTP messages and tokens. No full archive/DLP certification is claimed by this checklist.
- [ ] Decide whether sanitized local fixture identities in screenshots are appropriate for the institution's public repository rules.
- [ ] Verify final exported links/references and accessibility after layout conversion; repository link checks do not guarantee PDF navigation.

## Claims that must remain qualified

- [x] **87 Flutter / 69 backend** are recorded Phase 6 passes, not new Phase 7 execution.
- [x] Backend coverage **99.45% lines / 83.74% branches**, Flutter **76.84% reported lines**; native coverage absent.
- [x] **29 s** manual native scenario excludes build/install; **390.90 ms** local median excludes human/native time, n=5.
- [x] No participant study, biometric FAR/FRR, independent pentest, formal proof or certification is claimed.
- [x] No remote key attestation; emulator hardware backing false; physical Android/iOS validation absent.
- [x] Email step is not a claim of NIST-conformant out-of-band authentication or phishing resistance.
- [x] Signup enumeration/address reservation, recovery, dependency and operational gaps remain disclosed.
- [x] Release build is an unsigned audit artifact; no signed distribution or production-readiness claim.

## Technical gates outside this academic phase

The report's recommendations are future work, not completed tasks: remotely validated authenticator provenance/policy, safe account initiation/recovery, dependency remediation, retention/admission controls, physical-device/iOS validation and deployed TLS/SMTP/signing/monitoring/backup recovery. Their absence does not prevent an honest academic submission, but must prevent stronger security claims. Do not begin additional development phases without separate authorization.


## Documentation quality review record

Phase 7 review checked nine Markdown documents (eight new files and the root README),
183 local file/anchor links, all seven Mermaid blocks, the six report chapters,
38 defense questions and 15 slides. Evidence assertions independently recalculated
the Flutter percentage and local median and checked recorded test counts, coverage
fractions, native duration/backing and unsigned artifact facts. SHA-256 comparisons
confirmed all 59 pre-existing documentation/evidence/image files unchanged.
External references were checked at their primary publisher/maintainer pages.
These are documentation checks, not new Flutter/backend/native execution or final
PDF/slide rendering. Institutional review and export tasks above remain open.
