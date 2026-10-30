import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  // This host-only test driver feeds virtual fingerprint events to the OS sensor.
  // The app still requires a real CryptoObject authorization and server signature check.
  final requestedFingerprint =
      Platform.environment['AUTHVAULT_TEST_FINGERPRINT_ID'] ?? '1';
  final manual = requestedFingerprint == 'manual';
  final fingerprintId = int.tryParse(requestedFingerprint);
  if (!manual &&
      (fingerprintId == null || fingerprintId < 1 || fingerprintId > 10)) {
    throw ArgumentError(
      'AUTHVAULT_TEST_FINGERPRINT_ID must be 1–10 or manual.',
    );
  }
  bool running = true;
  Future<void> touch() async {
    while (running) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!running) return;
      final sdk =
          Platform.environment['ANDROID_SDK_ROOT'] ??
          Platform.environment['ANDROID_HOME'];
      final adb =
          Platform.environment['ADB'] ??
          (sdk != null
              ? '$sdk/platform-tools/adb'
              : (Platform.isMacOS
                    ? '${Platform.environment['HOME']}/Library/Android/sdk/platform-tools/adb'
                    : 'adb'));
      final result = await Process.run(adb, [
        '-s',
        'emulator-5554',
        'emu',
        'finger',
        'touch',
        fingerprintId.toString(),
      ]);
      if (result.exitCode != 0) {
        throw StateError(
          'Virtual fingerprint command failed; no authentication response was simulated.',
        );
      }
    }
  }

  final events = manual ? Future<void>.value() : touch();
  try {
    await integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final directory = Directory('docs/images/phase-6');
        await directory.create(recursive: true);
        await File('${directory.path}/$name.png').writeAsBytes(bytes);
        return true;
      },
      responseDataCallback: (data) async {
        await Directory('backend/.local').create(recursive: true);
        await File('backend/.local/phase-6-native-evidence.json').writeAsString(
          jsonEncode(
            data == null
                ? null
                : Map.fromEntries(
                    data.entries.where((entry) => entry.key != "screenshots"),
                  ),
          ),
        );
      },
    );
  } finally {
    running = false;
    await events;
  }
}
