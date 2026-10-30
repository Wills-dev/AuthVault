import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  // This host-only test driver feeds virtual fingerprint events to the OS sensor.
  // The app still requires a real CryptoObject authorization and server signature check.
  bool running = true;
  Future<void> touch() async {
    while (running) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!running) return;
      await Process.run('/Users/a0000/Library/Android/sdk/platform-tools/adb', [
        '-s',
        'emulator-5554',
        'emu',
        'finger',
        'touch',
        '1',
      ]);
    }
  }

  final events = touch();
  try {
    await integrationDriver(
      responseDataCallback: (data) async {
        await Directory('backend/.local').create(recursive: true);
        await File('backend/.local/biometric-native-evidence.json')
            .writeAsString(jsonEncode(data));
      },
    );
  } finally {
    running = false;
    await events;
  }
}
