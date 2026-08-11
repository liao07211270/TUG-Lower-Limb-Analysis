import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'movella_payload_parser.dart';

typedef SensorPayloadCallback = void Function(int sensorIndex, List<int> value);

/// 感測器量測 GATT 通道（跨錄製階段保留 Notify，避免重複進入時斷線）。
class SensorRuntimeChannels {
  final int sensorIndex;
  final BluetoothDevice device;
  final BluetoothCharacteristic? measurementControl;
  final List<BluetoothCharacteristic> payloadChars;

  const SensorRuntimeChannels({
    required this.sensorIndex,
    required this.device,
    required this.measurementControl,
    required this.payloadChars,
  });
}

/// 集中管理測試流程中的 BLE：錄製結束後保持連線與 Notify，僅離開設備流程時斷線。
class BleSessionManager {
  BleSessionManager._();
  static final BleSessionManager instance = BleSessionManager._();

  static const String _configurationServiceUuid = '15171000';
  static const String _deviceControlUuid = '15171002';
  static const String _measurementServiceUuid = '15172000';
  static const String _measurementControlUuid = '15172001';
  static const String _measurementPayloadUuid2 = '15172002';
  static const String _measurementPayloadUuid3 = '15172003';
  static const String _measurementPayloadUuid4 = '15172004';

  List<Map<String, dynamic>>? _activeSensors;
  SensorPayloadCallback? _payloadCallback;

  final List<List<StreamSubscription<List<int>>>> _payloadSubscriptions =
      List.generate(5, (_) => []);
  final List<SensorRuntimeChannels?> _runtimeChannels = List.filled(5, null);
  bool _notifyPipelineActive = false;

  void registerSensors(List<Map<String, dynamic>> sensors) {
    _activeSensors = sensors;
  }

  void clearRegistration() {
    _activeSensors = null;
  }

  List<Map<String, dynamic>> get activeSensors =>
      List<Map<String, dynamic>>.from(_activeSensors ?? const []);

  bool get hasActiveSession => _activeSensors != null;

  bool get notifyPipelineActive => _notifyPipelineActive;

  SensorRuntimeChannels? runtimeChannelAt(int index) {
    if (index < 0 || index >= _runtimeChannels.length) return null;
    return _runtimeChannels[index];
  }

  void setPayloadCallback(SensorPayloadCallback? callback) {
    _payloadCallback = callback;
  }

  /// 依實際 BLE 狀態更新 UI 上的 isConnected（避免顯示已連線但硬體已斷）。
  Future<void> syncSensorConnectionFlags(
    List<Map<String, dynamic>> sensors,
  ) async {
    for (int i = 0; i < sensors.length; i++) {
      final sensor = sensors[i];
      final device = sensor['device'];
      final connected = device is BluetoothDevice && device.isConnected;
      sensor['isConnected'] = connected;

      if (!connected) {
        if (i >= 0 && i < _runtimeChannels.length) {
          await _cancelPayloadSubscriptionsForIndex(i);
          _runtimeChannels[i] = null;
        }
        // 實體已斷線時清掉舊綁定，避免 UI 顯示或掃描判斷沿用失效裝置。
        sensor['isConnected'] = false;
        sensor['name'] = '等待綁定...';
        sensor['deviceId'] = '尚未配對';
        sensor['device'] = null;
        sensor['mac'] = null;
      }
    }
  }

  Future<SensorRuntimeChannels?> discoverRuntimeChannels(
    int sensorIndex,
    BluetoothDevice device,
  ) async {
    if (!device.isConnected) return null;

    try {
      final services =
          await device.discoverServices().timeout(const Duration(seconds: 10));

      BluetoothService? measurementService;
      for (var s in services) {
        if (s.uuid.str.contains(_measurementServiceUuid)) {
          measurementService = s;
          break;
        }
      }
      if (measurementService == null) return null;

      BluetoothCharacteristic? controlChar;
      final List<BluetoothCharacteristic> payloadChars = [];
      for (var c in measurementService.characteristics) {
        if (c.uuid.str.contains(_measurementControlUuid)) controlChar = c;
        if (c.uuid.str.contains(_measurementPayloadUuid2) ||
            c.uuid.str.contains(_measurementPayloadUuid3) ||
            c.uuid.str.contains(_measurementPayloadUuid4)) {
          payloadChars.add(c);
        }
      }

      if (payloadChars.isEmpty) return null;

      return SensorRuntimeChannels(
        sensorIndex: sensorIndex,
        device: device,
        measurementControl: controlChar,
        payloadChars: payloadChars,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> connectSensorIfNeeded(BluetoothDevice device) async {
    if (device.isConnected) return true;
    try {
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 20),
      ).timeout(const Duration(seconds: 22));
      await Future.delayed(const Duration(milliseconds: 200));
      return device.isConnected;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearSensorSlot(
    List<Map<String, dynamic>> sensors,
    int index, {
    bool disconnectDevice = false,
  }) async {
    if (index < 0 || index >= sensors.length) return;
    final sensor = sensors[index];
    final device = sensor['device'];

    if (device is BluetoothDevice) {
      await _stopMeasurementForDevice(device);
      await _disableNotifyForIndex(index);
      if (disconnectDevice && device.isConnected) {
        try {
          await device.disconnect().timeout(const Duration(seconds: 6));
        } catch (_) {}
      }
    }

    await _cancelPayloadSubscriptionsForIndex(index);
    if (index < _runtimeChannels.length) _runtimeChannels[index] = null;
    _clearSensorBinding(sensor);
    _notifyPipelineActive = _payloadSubscriptions.any((subs) => subs.isNotEmpty);
  }

  /// 啟用 Notify 並綁定資料回呼。
  ///
  /// [forceResubscribe]：第二次進入錄製頁時應為 true，避免沿用已失效的
  /// Stream 訂閱導致收不到封包、正式同步逾時。
  Future<void> activateNotifyPipeline(
    List<SensorRuntimeChannels> channels,
    SensorPayloadCallback onPayload, {
    bool forceResubscribe = false,
  }) async {
    _payloadCallback = onPayload;

    for (final ch in channels) {
      final idx = ch.sensorIndex;
      final existing = _runtimeChannels[idx];
      final sameDevice =
          existing != null &&
          existing.device.remoteId == ch.device.remoteId &&
          _payloadSubscriptions[idx].isNotEmpty;

      if (!sameDevice || forceResubscribe) {
        await _cancelPayloadSubscriptionsForIndex(idx);
        _runtimeChannels[idx] = ch;
        try {
          await _attachPayloadNotifyListeners(
            idx,
            ch,
            cycleNotify: forceResubscribe,
          );
        } catch (_) {
          await _cancelPayloadSubscriptionsForIndex(idx);
          _runtimeChannels[idx] = null;
          final reconnected = await connectSensorIfNeeded(ch.device);
          final fresh = reconnected
              ? await discoverRuntimeChannels(idx, ch.device)
              : null;
          if (fresh == null) rethrow;
          _runtimeChannels[idx] = fresh;
          await _attachPayloadNotifyListeners(idx, fresh, cycleNotify: false);
        }
      } else {
        _runtimeChannels[idx] = ch;
        if (_payloadSubscriptions[idx].isEmpty) {
          await _attachPayloadNotifyListeners(idx, ch);
        }
      }
    }

    _notifyPipelineActive = true;
  }

  /// 重新綁定 Notify；第二次進入錄製頁時 [cycleNotify] 先關再開，避免 Stream 僵死。
  Future<void> _attachPayloadNotifyListeners(
    int sensorIndex,
    SensorRuntimeChannels ch, {
    bool cycleNotify = false,
  }) async {
    if (!ch.device.isConnected) {
      throw StateError('感測器 ${sensorIndex + 1} 已斷線，無法啟用 Notify');
    }

    for (final char in ch.payloadChars) {
      if (cycleNotify) {
        try {
          if (char.isNotifying) {
            await char.setNotifyValue(false).timeout(const Duration(seconds: 4));
          }
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 80));
      }

      if (!ch.device.isConnected) {
        throw StateError('感測器 ${sensorIndex + 1} 已斷線，無法啟用 Notify');
      }

      try {
        await char.setNotifyValue(true).timeout(const Duration(seconds: 4));
      } catch (e) {
        await _cancelPayloadSubscriptionsForIndex(sensorIndex);
        _runtimeChannels[sensorIndex] = null;
        throw StateError('感測器 ${sensorIndex + 1} 啟用 Notify 失敗：$e');
      }

      _payloadSubscriptions[sensorIndex].add(
        char.lastValueStream.listen((value) {
          _payloadCallback?.call(sensorIndex, value);
        }),
      );
    }
  }

  /// 量測前設定輸出 60 Hz（Device control visit index b4）。
  Future<void> configureOutputRate60Hz(List<SensorRuntimeChannels> channels) async {
    final payload = List<int>.filled(32, 0);
    payload[0] = 0x10; // visit Output rate
    payload[24] = 60;
    payload[25] = 0;

    for (final ch in channels) {
      if (!ch.device.isConnected) continue;
      try {
        final services = ch.device.servicesList.isNotEmpty
            ? ch.device.servicesList
            : await ch.device.discoverServices().timeout(const Duration(seconds: 10));
        BluetoothCharacteristic? deviceControl;
        for (final s in services) {
          if (!s.uuid.str.contains(_configurationServiceUuid)) continue;
          for (final c in s.characteristics) {
            if (c.uuid.str.contains(_deviceControlUuid)) {
              deviceControl = c;
              break;
            }
          }
        }
        if (deviceControl == null) continue;
        await deviceControl
            .write(payload, withoutResponse: false)
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  Future<void> startMeasurement(List<SensorRuntimeChannels> channels) async {
    await configureOutputRate60Hz(channels);
    for (final c in channels) {
      if (c.measurementControl == null || !c.device.isConnected) continue;
      try {
        await c.measurementControl!
            .write([
              0x01,
              0x01,
              MovellaPayloadParser.rateQuantitiesMode,
            ], withoutResponse: false)
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  /// 錄製 UI 結束：僅卸載回呼，**不**送停止量測、**不**取消 Notify、**不**斷線。
  void releaseRecordingUi() {
    _payloadCallback = null;
  }

  /// 測試畫面結束但保留實體連線：停止量測並清掉 Notify/subscription。
  ///
  /// 第二次測試會重新 discover、重新訂閱 Notify、重新 start measurement，
  /// 避免沿用上一輪已僵住的 payload stream。
  Future<void> pauseRecordingKeepingConnections(
    List<Map<String, dynamic>> sensors,
  ) async {
    await stopMeasurementOnly(sensors);
    await _tearDownNotifyPipeline();
    await syncSensorConnectionFlags(sensors);
    final hasConnectedSensor = sensors.any((s) => s['isConnected'] == true);
    if (hasConnectedSensor) {
      registerSensors(sensors);
    } else {
      clearRegistration();
    }
  }

  /// 第二次進入錄製前：重啟量測輸出，避免 Notify 活著但無新封包。
  Future<void> restartMeasurement(List<SensorRuntimeChannels> channels) async {
    final sensors = _activeSensors ?? const [];
    await stopMeasurementOnly(sensors);
    await Future.delayed(const Duration(milliseconds: 120));
    await startMeasurement(channels);
  }

  /// 測試結束或離開設備頁時保留 BLE，僅同步連線旗標（不斷線、不清綁定）。
  Future<void> preserveSession(List<Map<String, dynamic>> sensors) async {
    if (sensors.isEmpty) return;
    await syncSensorConnectionFlags(sensors);
    final hasConnectedSensor = sensors.any((s) => s['isConnected'] == true);
    if (!hasConnectedSensor) {
      await _tearDownNotifyPipeline();
      clearRegistration();
      return;
    }
    registerSensors(sensors);
  }

  Future<void> stopMeasurementOnly(
    List<Map<String, dynamic>> sensors,
  ) async {
    for (final sensor in sensors) {
      final device = sensor['device'];
      if (device == null || device is! BluetoothDevice || !device.isConnected) {
        continue;
      }
      try {
        for (var s in device.servicesList) {
          if (s.uuid.str.contains(_measurementServiceUuid)) {
            for (var c in s.characteristics) {
              if (c.uuid.str.contains(_measurementControlUuid)) {
                await c.write([0x01, 0x00, 0x00], withoutResponse: false);
                break;
              }
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _stopMeasurementForDevice(BluetoothDevice device) async {
    if (!device.isConnected) return;
    try {
      for (var s in device.servicesList) {
        if (s.uuid.str.contains(_measurementServiceUuid)) {
          for (var c in s.characteristics) {
            if (c.uuid.str.contains(_measurementControlUuid)) {
              await c
                  .write([0x01, 0x00, 0x00], withoutResponse: false)
                  .timeout(const Duration(seconds: 4));
              return;
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _disableNotifyForIndex(int index) async {
    if (index < 0 || index >= _runtimeChannels.length) return;
    final ch = _runtimeChannels[index];
    if (ch == null || !ch.device.isConnected) return;
    for (final char in ch.payloadChars) {
      try {
        if (char.isNotifying) {
          await char.setNotifyValue(false).timeout(const Duration(seconds: 4));
        }
      } catch (_) {}
    }
  }

  Future<bool> disconnectSensorAt(
    List<Map<String, dynamic>> sensors,
    int index,
  ) async {
    if (index < 0 || index >= sensors.length) return false;
    final sensor = sensors[index];
    final device = sensor['device'];

    if (device is! BluetoothDevice) {
      _clearSensorBinding(sensor);
      return true;
    }

    await _stopMeasurementForDevice(device);
    await _disableNotifyForIndex(index);
    await _cancelPayloadSubscriptionsForIndex(index);
    if (index < _runtimeChannels.length) _runtimeChannels[index] = null;

    final disconnected = await _disconnectDeviceCompletely(device);

    if (!disconnected) return false;

    _clearSensorBinding(sensor);
    final hasAnySubscription = _payloadSubscriptions.any((subs) => subs.isNotEmpty);
    _notifyPipelineActive = hasAnySubscription;
    await preserveSession(sensors);
    return true;
  }

  void _clearSensorBinding(Map<String, dynamic> sensor) {
    sensor['isConnected'] = false;
    sensor['name'] = '等待綁定...';
    sensor['deviceId'] = '尚未配對';
    sensor['device'] = null;
    sensor['mac'] = null;
  }

  Future<void> _cancelPayloadSubscriptionsForIndex(int index) async {
    for (final sub in _payloadSubscriptions[index]) {
      await sub.cancel();
    }
    _payloadSubscriptions[index].clear();
  }

  Future<void> _tearDownNotifyPipeline() async {
    for (int i = 0; i < _payloadSubscriptions.length; i++) {
      await _cancelPayloadSubscriptionsForIndex(i);
      _runtimeChannels[i] = null;
    }
    _notifyPipelineActive = false;
    _payloadCallback = null;
  }

  Future<bool> _disconnectDeviceCompletely(BluetoothDevice device) async {
    var disconnected = !device.isConnected;
    for (int attempt = 0; attempt < 3 && !disconnected; attempt++) {
      try {
        await device.disconnect().timeout(const Duration(seconds: 8));
      } catch (_) {}
      try {
        await device.connectionState
            .firstWhere((s) => s == BluetoothConnectionState.disconnected)
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 250));
      disconnected = !device.isConnected;
    }
    return disconnected;
  }

  Future<bool> disconnectAll(List<Map<String, dynamic>> sensors) async {
    var allDisconnected = true;
    for (final sensor in sensors) {
      final device = sensor['device'];
      if (device == null || device is! BluetoothDevice) continue;
      final disconnected = await _disconnectDeviceCompletely(device);
      allDisconnected = allDisconnected && disconnected;
    }
    return allDisconnected;
  }

  /// 停止量測、取消 Notify、斷線（離開設備頁／切換分頁時使用）。
  Future<void> endSession({bool clearUiBindings = false}) async {
    final sensors = _activeSensors;
    if (sensors == null || sensors.isEmpty) {
      await _tearDownNotifyPipeline();
      clearRegistration();
      return;
    }

    await stopMeasurementOnly(sensors);
    await _tearDownNotifyPipeline();
    await disconnectAll(sensors);

    if (clearUiBindings) {
      for (final sensor in sensors) {
        final device = sensor['device'];
        final stillConnected = device is BluetoothDevice && device.isConnected;
        if (stillConnected) {
          sensor['isConnected'] = true;
        } else {
          _clearSensorBinding(sensor);
        }
      }
    }

    clearRegistration();
  }
}
