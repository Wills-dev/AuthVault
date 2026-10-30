# Evaluation plan

No authentication or biometric evaluation has been performed. No security or
performance success rate is claimed by Phase 1 widget tests.

Record build/commit, device/OS, biometric type, backend hardware, network, dataset,
trial count, exclusions and raw anonymized observations. Obtain participant consent;
store no biometric images, passwords, OTPs or tokens in measurement records.

| Metric | Definition | Current result |
| --- | --- | --- |
| Authentication success | completed authorized logins / valid full-flow attempts | Not measured |
| Genuine-user biometric success | successful OS-authorized signatures / genuine trials | Not measured |
| Impostor rejection | rejected impostor trials / impostor trials | Not measured |
| Response time | per-stage and end-to-end p50/p95, with sample count | Not measured |
| Unauthorized-access prevention | denied adversarial requests / adversarial requests | Not measured |

Measure real biometric outcomes on physical Android and iOS devices. Emulators and
mock signatures demonstrate flow behavior only. Report numerator, denominator and
uncertainty for rates; separate cancellations, hardware lockouts and network errors.
Record end-to-end human interaction separately from server latency. Test stage bypass,
challenge replay, wrong device, concurrent OTP consumption, OTP expiry/reuse,
refresh-token reuse, logout and direct protected-resource requests.

Automated security tests are planned for Phases 3–7. Device testing, performance
measurement and academic-defense rehearsal remain outstanding.


## Phase 6 measured evidence

See [coverage](test-coverage.md), [local measured performance](performance-evaluation.md),
[security audit](phase-6-security-audit.md) and [actual validation](phase-6-validation.md).
No physical biometric error rates, independent penetration test, formal certification
or production performance was measured. The final native full-flow retest passed with manual enrolled-fingerprint input
and the documented emulator rendering workaround (29 seconds excluding build/install).
Historical Phase 5 results do not substitute for this new Phase 6 evidence.
