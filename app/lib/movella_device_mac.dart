import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Movella DOT base UUID: 1517xxxx-4947-11E9-8646-D663BD873D93
/// Configuration service 0x1000, Device info characteristic 0x1001:
/// first 6 bytes = Bluetooth identity address (MAC).
Future<String?> readMovellaDotIdentityMac(BluetoothDevice device) async {
  try {
    BluetoothCharacteristic? deviceInfo;
    for (final s in device.servicesList) {
      if (!s.uuid.str.toLowerCase().contains('15171000')) continue;
      for (final c in s.characteristics) {
        if (c.uuid.str.toLowerCase().contains('15171001')) {
          deviceInfo = c;
          break;
        }
      }
      if (deviceInfo != null) break;
    }
    if (deviceInfo == null) return null;

    final data = await deviceInfo.read().timeout(const Duration(seconds: 4));
    if (data.length < 6) return null;

    return data
        .take(6)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':')
        .toUpperCase();
  } catch (_) {
    return null;
  }
}
