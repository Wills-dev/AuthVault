import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

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
      onScreenshot: (name, bytes, [args]) async {
        final directory = Directory('docs/images/phase-5');
        await directory.create(recursive: true);
        await File('${directory.path}/$name.png').writeAsBytes(bytes);
        return true;
      },
      responseDataCallback: (data) async {
        await Directory('backend/.local').create(recursive: true);
        await File('backend/.local/phase-5-native-evidence.json').writeAsString(
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
