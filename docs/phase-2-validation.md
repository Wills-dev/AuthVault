# Phase 2 validation — 29 October 2026

## Executed results

| Check | Actual result |
| --- | --- |
| Dart formatting | Passed: 21 Dart files; final check reported 0 changes |
| flutter analyze | Passed, exit 0: no issues found |
| flutter test | Passed, exit 0: 35 tests |
| Android screen inspection | Passed, exit 0: one on-device integration test plus teardown |
| flutter build apk --debug | Passed, exit 0: normal app APK built; final assembleDebug 14.0 s |
| Normal app launch | Passed, exit 0: normal APK launched on emulator-5554; foreground and rendered welcome screen verified |
| iOS / release build | Not run |
| Backend / cryptographic biometric verification | Not implemented or evaluated |

The first widget run exposed header overflow at 320 logical pixels and 200% text
scaling. The header was made flexible; all final layout checks pass. Visual review
also prompted separate screen/form identities to avoid carrying scroll or password
input between credential screens. The final suite tests credential state isolation.

## Widget/unit coverage

35 tests cover welcome navigation, email/password/name/confirmation validation,
password visibility with input preservation, informational MFA links, unavailable
recovery, honest unavailable submission, localized loading, duplicate submission
prevention, OTP numeric filtering/length/paste, invalid/expired error presentations,
timestamp countdown/expiry boundaries, six biometric readiness outcomes, protected
route redirects, debug-preview exit, release route policy and credential isolation.

The responsive matrix covers all seven screens at 320 × 568 and 568 × 320 logical
pixels, 200% system text scale, a 100-pixel keyboard inset and reduced-motion mode.
No framework layout exceptions were observed in those 14 cases. This does not
claim exhaustive coverage of every device, keyboard or accessibility configuration.
OTP/error/biometric fixtures are deterministic UI fixtures, not server/device proof.

## On-device screen inspection

Executed successfully on `emulator-5554`, sdk gphone64 arm64, Android 17 / API 37:

```sh
flutter drive --driver=test_driver/ui_gallery_driver.dart --target=integration_test/ui_gallery_test.dart -d emulator-5554
```

The test renders every screen using the actual Android runtime, queries biometric
capability without a platform mock, exercises protected-route redirect, checks for
framework exceptions and captures top/lower views of seven screens plus the gallery.
The final inspection run completed successfully (test body approximately 14 s;
its separate integration APK build reported 317.1 s). These are debug tooling
observations, not performance evaluation metrics.

Screenshots were visually inspected for hierarchy, readable content, aligned
controls and clipping. The emulator reported biometrics unavailable, and the
screen displayed that result without claiming identity verification. The driver
callback saves PNGs and returns true; it does not perform pixel-golden comparison.

| Screen | Capture |
| --- | --- |
| Welcome | [Image](images/phase-2/phase-2-welcome.png) |
| Login | [Image](images/phase-2/phase-2-login.png) |
| Registration | [Image](images/phase-2/phase-2-registration.png) |
| Biometric readiness | [Image](images/phase-2/phase-2-biometric.png) |
| OTP | [Image](images/phase-2/phase-2-otp.png) |
| Dashboard preview | [Image](images/phase-2/phase-2-dashboard.png) |
| Profile/security preview | [Image](images/phase-2/phase-2-profile.png) |
| Development gallery | [Image](images/phase-2/phase-2-gallery.png) |

## Build and normal launch

After inspection, the normal app entrypoint was rebuilt with `flutter build apk
--debug`; it exited 0 and produced `build/app/outputs/flutter-apk/app-debug.apk`.
The integration-test entrypoint is not used in that normal build.

Launch command:

```sh
flutter run -d emulator-5554 --debug --no-resident --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk
```

The normal launch command exited 0; installation reported 936 ms. adb confirmed
`com.example.authvault/.MainActivity` as the top resumed activity and process
10024 running. The rendered welcome screen was visually confirmed in the
[normal app capture](images/phase-2/normal-app-launch.png). The app was left running.

Java native-access warnings and Android rendering/hidden-API/debug-startup warnings
were non-fatal in the executed builds/inspection. No Android configuration changes
were made. iOS tooling remains incomplete; real-device biometrics, screen-reader
usability and release-binary verification remain outstanding.

## Phase gate

Phase 2 implementation and normal Android build/launch verification are complete.
No Phase 3 work has started. Approval is required before backend implementation.
Suggested commit: `feat: add authentication UI and guarded development previews`.
