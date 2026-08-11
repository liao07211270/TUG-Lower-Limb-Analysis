import 'dart:typed_data';

/// Movella DOT payload mode 21 — Rate quantities (28 bytes).
/// Timestamp(4) + Acceleration(12) + Angular velocity(12).
class MovellaPayloadParser {
  static const int rateQuantitiesMode = 0x15;

  static bool isRateQuantitiesPacket(List<int> value) =>
      value.length >= 28;

  static ({
    double accX,
    double accY,
    double accZ,
    double gyroX,
    double gyroY,
    double gyroZ,
  })? parseRateQuantities(List<int> value) {
    if (!isRateQuantitiesPacket(value)) return null;
    final byteData = ByteData.view(Uint8List.fromList(value).buffer);
    return (
      accX: byteData.getFloat32(4, Endian.little),
      accY: byteData.getFloat32(8, Endian.little),
      accZ: byteData.getFloat32(12, Endian.little),
      gyroX: byteData.getFloat32(16, Endian.little),
      gyroY: byteData.getFloat32(20, Endian.little),
      gyroZ: byteData.getFloat32(24, Endian.little),
    );
  }
}
