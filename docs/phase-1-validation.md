# Phase 1 validation — 29 October 2026

## Implemented

- Existing generated Flutter platform projects retained.
- Material 3 design tokens/theme and safe-area, scrollable app shell.
- Riverpod composition root and disposable GoRouter provider.
- Requested Flutter dependencies resolved and locked; integration-test SDK tooling.
- Backend boundary and architecture, API, dependency and evaluation documentation.
- Environment-secret ignores and Node version file.

## Actual results

| Check | Result |
| --- | --- |
| Flutter dependency resolution | Passed |
| Dart formatting check | Passed: 8 files, no changes needed |
| Flutter analyze | Passed: no issues found |
| Flutter test | Passed: 1 widget test |
| Small screen/text scaling | 320 × 568 at 200% system text scaling; no framework exception |
| Flutter doctor -v | Executed successfully (exit 0); Android toolchain/licenses pass; Xcode/CocoaPods issue remains |
| Android debug APK | Passed: flutter build apk --debug (exit 0); assembleDebug reported 123.0 seconds |
| Android emulator launch | Passed: flutter run with built APK on emulator-5554 (exit 0); foreground activity and rendered foundation screen verified |
| iOS build | Not run: full Xcode and CocoaPods missing |
| Backend/database/security tests | Not applicable yet; backend not implemented |
| Real-device biometric tests | Not run |

The PascalCase reusable widget filename is intentional per the project request;
a file-local file_names lint exception preserves normal linting elsewhere.
Generated release signing still uses development configuration and must be replaced
before distribution. SDK build warnings are not security test results.

## Android blocker resolution and verification

The initial build failed during SDK provisioning. On this follow-up inspection,
SDK Manager already reported the required packages installed. No new download was
needed: the command to ensure all three packages were installed completed with
exit 0. Do not attribute their earlier installation to this verification run.

`android/app/build.gradle.kts` uses `compileSdk = flutter.compileSdkVersion` and
`ndkVersion = flutter.ndkVersion`. The installed Flutter 3.47.9 SDK's
`packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt` defines:

| Requirement | Required version | Verified installation |
| --- | --- | --- |
| Compile/target SDK | 36 | platforms/android-36, package revision 2.0.0 |
| Build Tools | 36.0.0 | build-tools/36.0.0 |
| NDK | 28.2.13676358 | ndk/28.2.13676358; source.properties confirms r28c |

SDK root: `/Users/a0000/Library/Android/sdk`. SDK Manager also lists CMake 3.22.1.
No project configuration, architecture, or application code changed for this fix.

Executed commands (all completed with exit 0):

```sh
/Users/a0000/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=/Users/a0000/Library/Android/sdk --list_installed
/Users/a0000/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=/Users/a0000/Library/Android/sdk 'ndk;28.2.13676358' 'platforms;android-36' 'build-tools;36.0.0'
flutter doctor -v
flutter analyze
flutter test
flutter build apk --debug
flutter run -d emulator-5554 --debug --no-resident --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk
```

APK: `build/app/outputs/flutter-apk/app-debug.apk`. Emulator: sdk gphone64 arm64,
Android 17 / API 37. Flutter's APK installation took 156.9 seconds. After launch,
adb reported `com.example.authvault/.MainActivity` as `topResumedActivity` and
`pidof com.example.authvault` returned process 8624. A screenshot was inspected:
the AuthVault title, “Security at every step.” and foundation card rendered after
the native splash. See [emulator screenshot](images/phase-1-android.png).
The non-resident Flutter command exited successfully while leaving the app running.

Non-fatal warnings included Java native-access warnings, SDK XML version mismatch,
Android hidden-API/rendering warnings and skipped frames during debug startup.
The build and rendered screen were confirmed despite these warnings. This is a
debug emulator smoke check, not a performance benchmark or biometric security test.
Full Xcode and CocoaPods remain missing; iOS was not built or launched.

## Phase gate

Suggested commit: `chore: initialize AuthVault architecture and design system`

Phase 2 must not begin until the user approves it. It will introduce authentication
screens and navigation; successful backend behavior must not be fabricated.
