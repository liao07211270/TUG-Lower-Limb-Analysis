import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'result_screen.dart';
import '../ble_session.dart';
import '../tug_analysis_pipeline2.dart';
import '../database_helper.dart';
import '../imu_column_layout.dart';
import '../imu_series_storage.dart';
import '../movella_payload_parser.dart';

enum _RecordingPhase {
  preparing,
  readyToStart,
  resyncing,
  recording,
}

// === 主題配色 ===
const Color bgCream    = Color(0xFFF9F2EF);
const Color primaryOrange = Color(0xFFF98C53);
const Color accentGreen = Color(0xFFD2E0AA);
const Color textDark   = Color(0xFF4A4A4A);
const Color textLight  = Color(0xFF9E9E9E);

// ─────────────────────────────────────────────────────────────────────────────
// [DEBUG] 統一 debug log。確認穩定後刪除：
//   1. _dbg() 函式本體
//   2. 所有 _dbg(...) 呼叫（全域搜尋 "_dbg(" 即可）
//   3. _phaseStopwatch 欄位與所有 .reset()/.start()/.elapsedMilliseconds 呼叫
// ─────────────────────────────────────────────────────────────────────────────
void _dbg(String tag, String message) {
  debugPrint('[$tag] $message');
}

class TugRecordingScreen extends StatefulWidget {
  final List<Map<String, dynamic>> sensors;
  final bool isGuest;
  final int? userId;

  const TugRecordingScreen({
    super.key,
    required this.sensors,
    this.isGuest = false,
    this.userId,
  });

  @override
  State<TugRecordingScreen> createState() => _TugRecordingScreenState();
}

class _TugRecordingScreenState extends State<TugRecordingScreen> {
  int _currentIndex = 0;

  // ─── 碼表（所有感測器共用，第一筆封包到達時啟動） ───────────────────────
  final Stopwatch _sessionClock = Stopwatch();

  // ─────────────────────────────────────────────────────────────────────────
  // 軟體時間對齊核心欄位
  //
  // _firstPacketArrival[i]：感測器 i 的第一筆封包抵達時，_sessionClock 的讀數（秒）。
  //   index 0 固定為 0.0（它啟動了碼表）；其他顆 > 0 代表「比第一顆晚了多少秒才送資料」。
  //
  // _sensorOffset[i] = _firstPacketArrival[i]
  //   之後每筆資料的統一時間戳 tSec = 碼表時間 − _sensorOffset[i]
  //   這樣所有感測器的 tSec=0 都對齊到「各自第一筆封包的那一刻」。
  //
  // _softSyncReady：true 表示 5 顆都已收到第一筆封包，可以開始寫入 _recordedData。
  //
  // [DEBUG] 確認對齊正確後，可保留欄位但移除 _dbg 呼叫。
  // ─────────────────────────────────────────────────────────────────────────
  final Map<int, double> _firstPacketArrival = {};
  final Map<int, double> _sensorOffset       = {};
  bool _softSyncReady = false;

  // 等待 5 顆都就緒的逾時計時器（超過 5 秒仍有感測器無資料 → 詢問使用者）
  Timer? _softSyncWatchdog;
  // 逾時後已顯示過對話框的標記，避免重複觸發
  bool _softSyncTimeoutHandled = false;

  int? _masterSensorIndex;
  Timer? _uiTimer;
  Timer? _recordSampleTimer;
  static const double _recordSampleRateHz = 60.0;
  double _elapsedSeconds = 0.0;

  /// 各感測器最新一筆 IMU（60 Hz 定時組列用，與圖表緩衝分離）。
  final List<List<double>?> _latestImuSample =
      List.filled(5, null);

  bool _recordingUiActive  = false;
  bool _intentionalShutdown = false;
  bool _disconnectDialogShown = false;
  bool _keepBleOnDispose = false;

  _RecordingPhase _phase = _RecordingPhase.preparing;

  final List<List<dynamic>> _recordedData = [];

  bool   _isInitializing = true;
  bool   _isAnalyzing = false;
  String _initStatus = "準備連線...";

  final List<List<List<FlSpot>>> _accData  = List.generate(5, (_) => [[], [], []]);
  final List<List<List<FlSpot>>> _gyroData = List.generate(5, (_) => [[], [], []]);
  final double _windowSize = 5.0;

  final List<StreamSubscription<BluetoothConnectionState>> _connectionSubscriptions = [];

  // [DEBUG] 各階段計時器
  final Stopwatch _phaseStopwatch = Stopwatch();

  // ─── 生命週期 ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    BleSessionManager.instance.registerSensors(widget.sensors);
    _dbg('INIT', '進入 TugRecordingScreen，感測器數量=${widget.sensors.length}');
    _setupBluetoothAndStart().timeout(
      const Duration(seconds: 120),
      onTimeout: () async {
        _dbg('TIMEOUT', '整體初始化超過 120 秒');
        await _showSafeDialog(_buildAlertDialog(
          title: '初始化逾時',
          content: '請確認感測器電量與藍牙狀態後重試。',
          onConfirm: () {
            Navigator.of(context).pop();
            unawaited(_popToDeviceResettingBle());
          },
        ));
      },
    );
  }

  @override
  void dispose() {
    _intentionalShutdown = true;
    _sessionClock.stop();
    _uiTimer?.cancel();
    _stopRecordSampleTimer();
    _softSyncWatchdog?.cancel();

    for (final sub in _connectionSubscriptions) sub.cancel();
    _connectionSubscriptions.clear();

    if (_keepBleOnDispose) {
      BleSessionManager.instance.releaseRecordingUi();
    } else {
      Future(() async {
        await BleSessionManager.instance.endSession(clearUiBindings: true);
      });
    }

    super.dispose();
  }

  // ─── 幫手函數 ─────────────────────────────────────────────────────────────

  void _showSafeSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 1),
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: duration),
      );
    });
  }

  Future<void> _showSafeDialog(Widget dialog) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showDialog(context: context, barrierDismissible: false, builder: (_) => dialog);
    });
  }

  AlertDialog _buildAlertDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
    String confirmLabel = '確定',
    String? cancelLabel,
    VoidCallback? onCancel,
  }) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(color: textDark, fontWeight: FontWeight.w900)),
      content: Text(content, style: const TextStyle(color: textDark, height: 1.4)),
      actions: [
        if (cancelLabel != null && onCancel != null)
          TextButton(onPressed: onCancel, child: Text(cancelLabel, style: const TextStyle(color: textLight))),
        TextButton(
          onPressed: onConfirm,
          child: Text(confirmLabel, style: const TextStyle(color: primaryOrange, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  // ─── BLE 清理 ─────────────────────────────────────────────────────────────

  Future<void> _cancelConnectionSubscriptions() async {
    for (final sub in _connectionSubscriptions) await sub.cancel();
    _connectionSubscriptions.clear();
  }

  Future<void> _releaseRecordingSession({required bool disconnectDevices}) async {
    await _cancelConnectionSubscriptions();
    if (disconnectDevices) {
      await BleSessionManager.instance.endSession(clearUiBindings: true);
    } else {
      await BleSessionManager.instance.pauseRecordingKeepingConnections(
        widget.sensors,
      );
    }
  }

  Future<void> _popToDeviceResettingBle() async {
    _keepBleOnDispose = true;
    _intentionalShutdown = true;
    _sessionClock.stop();
    _uiTimer?.cancel();
    _stopRecordSampleTimer();
    _softSyncWatchdog?.cancel();
    await _releaseRecordingSession(disconnectDevices: true);
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  void _attachConnectionListeners() {
    for (int i = 0; i < widget.sensors.length; i++) {
      final d = widget.sensors[i]['device'];
      if (d == null || d is! BluetoothDevice) continue;
      _connectionSubscriptions.add(
        d.connectionState.listen((state) {
          if (state != BluetoothConnectionState.disconnected) return;
          if (_intentionalShutdown || !_recordingUiActive || _disconnectDialogShown) return;
          _onSensorDisconnectedUnexpectedly();
        }),
      );
    }
  }

  // ─── GATT 通道建立（含重試） ──────────────────────────────────────────────

  // ─── 軟體時間對齊：逾時保護 ──────────────────────────────────────────────
  //
  // 啟動量測指令送出後，開始等待所有感測器的第一筆封包。
  // 若 5 秒內仍有感測器未送出任何資料，詢問使用者：
  //   - 略過該顆繼續錄製（以現有感測器的資料為主）
  //   - 中止並返回連線畫面
  //
  void _startSoftSyncWatchdog(int totalSensors) {
    _softSyncWatchdog?.cancel();
    _softSyncWatchdog = Timer(const Duration(seconds: 5), () async {
      if (_softSyncReady || _softSyncTimeoutHandled || !mounted) return;

      final missingSensors = <String>[];
      for (int i = 0; i < totalSensors; i++) {
        if (!_firstPacketArrival.containsKey(i)) {
          missingSensors.add(widget.sensors[i]['part']?.toString() ?? '感測器 $i');
        }
      }

      if (missingSensors.isEmpty) return;

      _softSyncTimeoutHandled = true;
      _dbg('SOFTSYNC', '逾時，未收到資料的感測器：$missingSensors');

      if (!mounted) return;
      await _showSafeDialog(_buildAlertDialog(
        title: '同步失敗',
        content:
            '5 秒內未收到全部感測器資料：\n${missingSensors.join('、')}\n\n'
            '系統會重置本次 BLE 連線，請返回設備頁重新綁定後再測試。',
        onConfirm: () async {
          Navigator.of(context).pop();
          await _popToDeviceResettingBle();
        },
      ));
    });
  }

  void _clearLiveChartBuffers() {
    for (int i = 0; i < 5; i++) {
      for (int a = 0; a < 3; a++) {
        _accData[i][a].clear();
        _gyroData[i][a].clear();
      }
      _latestImuSample[i] = null;
    }
  }

  void _resetSoftSyncRuntime({bool clearCharts = false}) {
    _softSyncReady = false;
    _softSyncTimeoutHandled = false;
    _firstPacketArrival.clear();
    _sensorOffset.clear();
    _masterSensorIndex = null;
    _sessionClock.stop();
    _sessionClock.reset();
    _elapsedSeconds = 0.0;
    _recordedData.clear();
    _stopRecordSampleTimer();
    if (clearCharts) _clearLiveChartBuffers();
  }

  void _resetSyncStateForFormalStart() {
    _resetSoftSyncRuntime(clearCharts: true);
  }

  bool _sensorHasLiveData(int index) =>
      _latestImuSample[index] != null || _accData[index][0].isNotEmpty;

  void _checkSoftSyncComplete() {
    if (_softSyncReady || _softSyncTimeoutHandled) return;
    if (_firstPacketArrival.length != widget.sensors.length) return;
    _softSyncWatchdog?.cancel();
    _softSyncReady = true;
    _dbg('SOFTSYNC', 'softSyncReady=true，所有感測器偏移：$_sensorOffset');
    _onAllSensorsAligned();
  }

  /// 正式錄製前：若 5 顆仍在出資料，不必等「下一筆第一包」才對齊。
  void _tryCompleteFormalResyncFromLiveStreams() {
    if (_phase != _RecordingPhase.resyncing) return;

    for (int i = 0; i < widget.sensors.length; i++) {
      final device = widget.sensors[i]['device'];
      if (device is! BluetoothDevice || !device.isConnected) return;
      if (!_sensorHasLiveData(i)) return;
    }

    if (!_sessionClock.isRunning) {
      _sessionClock.start();
    }

    for (int i = 0; i < widget.sensors.length; i++) {
      if (_firstPacketArrival.containsKey(i)) continue;
      if (_masterSensorIndex == null) {
        _masterSensorIndex = i;
        _firstPacketArrival[i] = 0.0;
        _sensorOffset[i] = 0.0;
        _dbg('SOFTSYNC', '正式錄製即時對齊：感測器 $i 為 Master');
      } else {
        final arrivalTime = _sessionClock.elapsedMicroseconds / 1000000.0;
        _firstPacketArrival[i] = arrivalTime;
        _sensorOffset[i] = arrivalTime;
      }
    }

    _checkSoftSyncComplete();
  }

  void _onAllSensorsAligned() {
    if (_phase == _RecordingPhase.preparing) {
      setState(() => _phase = _RecordingPhase.readyToStart);
      _showSafeSnackBar('感測器同步完成，請受試者就位後按「開始即時測試」');
    } else if (_phase == _RecordingPhase.resyncing) {
      _clearLiveChartBuffers();
      _sessionClock.stop();
      _sessionClock.reset();
      _sessionClock.start();
      setState(() {
        _phase = _RecordingPhase.recording;
        _elapsedSeconds = 0.0;
      });
      _startRecordSampleTimer();
      _showSafeSnackBar('開始錄製，請受試者執行 TUG', duration: const Duration(seconds: 1));
    }
  }

  void _startRecordSampleTimer() {
    _stopRecordSampleTimer();
    final periodUs = (1000000 / _recordSampleRateHz).round();
    _recordSampleTimer = Timer.periodic(
      Duration(microseconds: periodUs),
      (_) {
        if (!mounted ||
            _phase != _RecordingPhase.recording ||
            !_softSyncReady) {
          return;
        }
        _buildAndAppendRow();
      },
    );
  }

  void _stopRecordSampleTimer() {
    _recordSampleTimer?.cancel();
    _recordSampleTimer = null;
  }

  void _onUserStartFormalTest() {
    if (_phase != _RecordingPhase.readyToStart) return;
    setState(() {
      _resetSyncStateForFormalStart();
      _phase = _RecordingPhase.resyncing;
    });
    _tryCompleteFormalResyncFromLiveStreams();
    if (!_softSyncReady) {
      _startSoftSyncWatchdog(widget.sensors.length);
    }
  }

  // ─── 非預期斷線 ───────────────────────────────────────────────────────────

  Future<void> _onSensorDisconnectedUnexpectedly() async {
    if (_disconnectDialogShown || !mounted) return;
    _disconnectDialogShown = true;
    _intentionalShutdown = true;
    _sessionClock.stop();
    _uiTimer?.cancel();
    _stopRecordSampleTimer();
    _softSyncWatchdog?.cancel();
    _dbg('DISCONNECT', '偵測到非預期斷線');

    await _releaseRecordingSession(disconnectDevices: true);

    await _showSafeDialog(_buildAlertDialog(
      title: '連線中斷',
      content: '感測器已斷開連接，請重新測試。',
      onConfirm: () {
        Navigator.of(context).pop();
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/device_connection', (_) => false);
        }
      },
    ));
  }

  // ─── 主初始化流程 ─────────────────────────────────────────────────────────
  //
  // 新流程（移除硬體同步，改用軟體時間對齊）：
  //   1. 對每顆感測器 connect + discoverServices
  //   2. 啟動 Notify + 送出量測啟動指令
  //   3. 第一筆封包到達時記錄時間，計算 _sensorOffset
  //   4. 所有顆都就緒（或逾時略過）後，開始寫入 _recordedData
  //
  Future<void> _setupBluetoothAndStart() async {
    final session = BleSessionManager.instance;
    final List<SensorRuntimeChannels> channels = [];
    _dbg('SETUP', '開始初始化，感測器數量：${widget.sensors.length}');

    _softSyncWatchdog?.cancel();
    _resetSoftSyncRuntime(clearCharts: true);
    final bool hadNotifyPipeline = session.notifyPipelineActive;

    await session.syncSensorConnectionFlags(widget.sensors);

    for (int i = 0; i < widget.sensors.length; i++) {
      final sensor = widget.sensors[i];
      final device = sensor['device'];
      if (device == null || device is! BluetoothDevice) {
        _dbg('SETUP', '${sensor['part']} 無裝置物件，跳過');
        continue;
      }

      setState(() => _initStatus = '正在喚醒 ${sensor['part']}…');

      try {
        if (!device.isConnected) {
          _dbg('SETUP', '${sensor['part']} 未連線，重新連線');
          _phaseStopwatch.reset();
          _phaseStopwatch.start();
          final ok = await session.connectSensorIfNeeded(device);
          _dbg('SETUP', '${sensor['part']} 連線耗時 ${_phaseStopwatch.elapsedMilliseconds}ms ok=$ok');
          sensor['isConnected'] = ok;
        }
        if (!device.isConnected) {
          await _showSafeDialog(_buildAlertDialog(
            title: '初始化失敗',
            content: '${sensor['part']} 連線後仍為未連線狀態，請重試。',
            onConfirm: () {
              Navigator.of(context).pop();
              unawaited(_popToDeviceResettingBle());
            },
          ));
          return;
        }

        setState(() => _initStatus = '正在讀取 ${sensor['part']} 服務…');
        // 每次進入錄製都重新 discover，避免第二次測試沿用上一輪失效的 GATT characteristic。
        SensorRuntimeChannels? ch =
            await session.discoverRuntimeChannels(i, device);
        if (ch == null) {
          await _showSafeDialog(_buildAlertDialog(
            title: '初始化失敗',
            content: '${sensor['part']} 找不到量測服務，請確認感測器電量後重試。',
            onConfirm: () {
              Navigator.of(context).pop();
              unawaited(_popToDeviceResettingBle());
            },
          ));
          return;
        }
        channels.add(ch);
        _dbg('SETUP', '${sensor['part']} 初始化完成（channels=${channels.length}）');
      } catch (e) {
        _dbg('SETUP', '${sensor['part']} 初始化例外: $e');
        await _showSafeDialog(_buildAlertDialog(
          title: '初始化失敗',
          content: '${sensor['part']} 初始化失敗：$e',
          onConfirm: () {
            Navigator.of(context).pop();
            unawaited(_popToDeviceResettingBle());
          },
        ));
        return;
      }
    }

    if (channels.isEmpty) {
      await _showSafeDialog(_buildAlertDialog(
        title: '初始化失敗',
        content: '找不到任何可用的感測器通道。',
        onConfirm: () {
          Navigator.of(context).pop();
          unawaited(_popToDeviceResettingBle());
        },
      ));
      return;
    }

    if (channels.length != widget.sensors.length) {
      _dbg('SETUP', '通道數量不足：${channels.length}/${widget.sensors.length}');
      await _showSafeDialog(_buildAlertDialog(
        title: '初始化失敗',
        content: '只有 ${channels.length}/${widget.sensors.length} 顆感測器初始化成功，'
                 '請確認全部 5 顆皆連線後重試。',
        onConfirm: () {
          Navigator.of(context).pop();
          unawaited(_popToDeviceResettingBle());
        },
      ));
      return;
    }

    setState(() => _initStatus = '啟動感測器量測中…');
    _dbg('SETUP', '綁定 Notify（保留跨次連線）並啟動量測');

    try {
      await session.activateNotifyPipeline(
        channels,
        _parseSensorData,
        forceResubscribe: true,
      );
      if (hadNotifyPipeline) {
        _dbg('SETUP', '第二次進入：重啟量測輸出');
        await session.restartMeasurement(channels);
      } else {
        await session.startMeasurement(channels);
      }
    } catch (e) {
      _dbg('SETUP', '啟動 Notify/量測失敗: $e');
      await _releaseRecordingSession(disconnectDevices: true);
      await _showSafeDialog(_buildAlertDialog(
        title: '初始化失敗',
        content: '感測器啟動量測失敗，已重置連線狀態。請回到感測器連線頁重新綁定後再測試。\n\n$e',
        onConfirm: () {
          Navigator.of(context).pop();
          if (Navigator.canPop(context)) Navigator.of(context).pop();
        },
      ));
      return;
    }

    // ── 步驟 3：等待所有感測器第一筆封包（含逾時保護） ────────────────────
    //
    // _parseSensorData 內會逐一記錄 _firstPacketArrival，
    // 並在 5 顆全數就緒時將 _softSyncReady 設為 true。
    // 若 5 秒內未全數就緒，_startSoftSyncWatchdog 會詢問使用者。
    //
    setState(() => _initStatus = '等待感測器資料…（最多 5 秒）');
    _dbg('SETUP', '啟動軟體同步 Watchdog');
    _startSoftSyncWatchdog(channels.length);

    // 進入錄製畫面（不等 softSyncReady，畫面先顯示，資料就緒後才寫入）
    if (!mounted) return;
    setState(() => _isInitializing = false);
    _recordingUiActive = true;
    _attachConnectionListeners();

    _uiTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds = _sessionClock.isRunning
            ? _sessionClock.elapsedMicroseconds / 1000000.0
            : 0.0;
      });
    });

    _dbg('SETUP', '初始化完成，進入錄製畫面');
  }

  // ─── 資料解析與軟體時間對齊 ──────────────────────────────────────────────
  //
  // 軟體時間對齊流程：
  //
  //   首次收到某感測器資料時：
  //     若碼表尚未啟動（第一顆）→ 啟動碼表，_firstPacketArrival[i] = 0.0
  //     若已啟動（後續顆）→ _firstPacketArrival[i] = 碼表當前時間
  //     _sensorOffset[i] = _firstPacketArrival[i]
  //
  //   每筆資料的統一時間戳：
  //     tSec = 碼表時間 − _sensorOffset[i]
  //     → 所有感測器的 tSec=0 對齊到「各自第一筆封包那一刻」
  //
  //   全部 5 顆都收到第一筆封包後：
  //     _softSyncReady = true → 開始寫入 _recordedData
  //
  // [DEBUG] 對齊正確後可移除 _dbg 呼叫，保留邏輯。
  //
  void _parseSensorData(int sensorIndex, List<int> value) {
    if (!mounted || _disconnectDialogShown) return;
    final sample = MovellaPayloadParser.parseRateQuantities(value);
    if (sample == null) return;

    final accX = sample.accX;
    final accY = sample.accY;
    final accZ = sample.accZ;
    final gyroX = sample.gyroX;
    final gyroY = sample.gyroY;
    final gyroZ = sample.gyroZ;

    _latestImuSample[sensorIndex] = [
      accX, accY, accZ, gyroX, gyroY, gyroZ,
    ];

    // ── 軟體時間對齊：記錄第一筆封包到達時間 ──────────────────────────────
    if (!_firstPacketArrival.containsKey(sensorIndex)) {
      if (!_sessionClock.isRunning) {
        // 第一顆到達 → 啟動碼表，偏移為 0
        _sessionClock.start();
        _masterSensorIndex = sensorIndex;
        _firstPacketArrival[sensorIndex] = 0.0;
        _sensorOffset[sensorIndex]       = 0.0;
        _dbg('SOFTSYNC', // [DEBUG]
          '感測器 $sensorIndex (${widget.sensors[sensorIndex]['part']}) '
          '為 Master，offset=0.0，碼表啟動',
        );
      } else {
        // 後續顆到達 → 記錄偏移
        final arrivalTime = _sessionClock.elapsedMicroseconds / 1000000.0;
        _firstPacketArrival[sensorIndex] = arrivalTime;
        _sensorOffset[sensorIndex]       = arrivalTime;
        _dbg('SOFTSYNC', // [DEBUG]
          '感測器 $sensorIndex (${widget.sensors[sensorIndex]['part']}) '
          '第一筆到達，offset=$arrivalTime 秒',
        );
      }

      _checkSoftSyncComplete();
    }

    // ── 計算統一時間戳 ──────────────────────────────────────────────────────
    final double offset = _sensorOffset[sensorIndex] ?? 0.0;
    final double rawTime = _sessionClock.isRunning
        ? _sessionClock.elapsedMicroseconds / 1000000.0
        : 0.0;
    final double tSec = rawTime - offset;

    // ── 寫入圖表資料（即時顯示，不受 softSyncReady 限制） ──────────────────
    _accData[sensorIndex][0].add(FlSpot(tSec, accX));
    _accData[sensorIndex][1].add(FlSpot(tSec, accY));
    _accData[sensorIndex][2].add(FlSpot(tSec, accZ));
    _gyroData[sensorIndex][0].add(FlSpot(tSec, gyroX));
    _gyroData[sensorIndex][1].add(FlSpot(tSec, gyroY));
    _gyroData[sensorIndex][2].add(FlSpot(tSec, gyroZ));

    // 移除超出視窗的舊資料
    for (int axis = 0; axis < 3; axis++) {
      if (_accData[sensorIndex][axis].isNotEmpty &&
          _accData[sensorIndex][axis].first.x < tSec - _windowSize) {
        _accData[sensorIndex][axis].removeAt(0);
      }
      if (_gyroData[sensorIndex][axis].isNotEmpty &&
          _gyroData[sensorIndex][axis].first.x < tSec - _windowSize) {
        _gyroData[sensorIndex][axis].removeAt(0);
      }
    }

  }

  // ─── 組合資料列並寫入 ─────────────────────────────────────────────────────

  void _buildAndAppendRow() {
    for (int i = 0; i < widget.sensors.length; i++) {
      if (_latestImuSample[i] == null) return;
    }

    final row = List<dynamic>.filled(ImuColumnLayout.rowWidth, 0.0);
    for (int i = 0; i < widget.sensors.length; i++) {
      final part = widget.sensors[i]['part']?.toString();
      final imu = _latestImuSample[i];
      if (part == null ||
          imu == null ||
          ImuColumnLayout.rowStartForPart(part) == null) {
        return;
      }
      ImuColumnLayout.writeSensorToRow(
        row,
        part,
        imu[0],
        imu[1],
        imu[2],
        imu[3],
        imu[4],
        imu[5],
      );
    }
    _recordedData.add(row);
  }

  // ─── 結束測試 ─────────────────────────────────────────────────────────────

  Future<void> _finishTest() async {
    _intentionalShutdown = true;
    _sessionClock.stop();
    _uiTimer?.cancel();
    _stopRecordSampleTimer();
    _softSyncWatchdog?.cancel();
    final durationSec = _elapsedSeconds > 0 ? _elapsedSeconds : 0.001;
    final rowsPerSec = _recordedData.length / durationSec;
    _dbg(
      'FINISH',
      'recordedData=${_recordedData.length} 列, '
      '約 ${rowsPerSec.toStringAsFixed(1)} 列/秒 (目標 $_recordSampleRateHz)',
    );

    if (mounted) setState(() => _isAnalyzing = true);

    try {
      _keepBleOnDispose = true;
      await _releaseRecordingSession(disconnectDevices: false);

      final pipeline = TugAnalysisPipeline2();
      final TugResult result = await pipeline.runAnalysis(_recordedData);
      _dbg('FINISH', '分析完成：totalTime=${result.totalTime}');

      final String phaseLabel = result.totalTime > 15.0
          ? '需要注意'
          : (result.totalTime > 12.0 ? '輕微波動' : '平穩');

      final analysisMeta = {
        'totalTime': result.totalTime,
        'standUpTime': result.standUpTime,
        'walkGoTime': result.walkGoTime,
        'turn1Time': result.turn1Time,
        'walkReturnTime': result.walkReturnTime,
        'turn2Time': result.turn2Time,
        'sitDownTime': result.sitDownTime,
        'phase': phaseLabel,
      };

      final recordedAt = DateTime.now();
      int? historyId;
      String? imuJsonPath;
      imuJsonPath = await ImuSeriesStorage.saveRows(
        _recordedData,
        recordedAt: recordedAt,
        analysisResult: analysisMeta,
      );
      if (!widget.isGuest && widget.userId != null) {
        historyId = await DatabaseHelper.instance.insertHistory({
          'date':         recordedAt.toIso8601String().split('T')[0],
          'total_time':   result.totalTime,
          'stand_up':     result.standUpTime,
          'walk_go':      result.walkGoTime,
          'turn1':        result.turn1Time,
          'walk_return':  result.walkReturnTime,
          'turn2':        result.turn2Time,
          'sit_down':     result.sitDownTime,
          'phase':        phaseLabel,
          'user_id':      widget.userId,
        });
        await DatabaseHelper.instance.updateHistoryImuPath(historyId, imuJsonPath);
        _dbg('FINISH', '歷史記錄已寫入，historyId=$historyId');
      } else {
        _dbg('FINISH', '訪客模式 IMU 已存：$imuJsonPath');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => TugResultScreen(
                totalTime: result.totalTime,
                standUpTime: result.standUpTime,
                walkGoTime: result.walkGoTime,
                turn1Time: result.turn1Time,
                walkReturnTime: result.walkReturnTime,
                turn2Time: result.turn2Time,
                sitDownTime: result.sitDownTime,
                historyId: historyId,
                imuJsonPath: imuJsonPath,
                imuRowCount: _recordedData.length,
              ),
        ),
      );
    } catch (e) {
      _dbg('FINISH', '處理失敗: $e');
      if (mounted) {
        setState(() => _isAnalyzing = false);
        await _showSafeDialog(_buildAlertDialog(
          title: '處理失敗',
          content: '步態分析發生錯誤，請稍後再試。',
          onConfirm: () {
            Navigator.of(context).pop();
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          },
        ));
      }
    }
  }

  Future<void> _confirmLeaveRecording() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('離開錄製', style: TextStyle(color: textDark, fontWeight: FontWeight.w900)),
        content: const Text('確定要離開嗎？將停止本次錄製並返回設備管理（感測器保持連線）。',
          style: TextStyle(color: textDark, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: textLight))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確定',
              style: TextStyle(color: primaryOrange, fontWeight: FontWeight.w800))),
        ],
      ),
    ) ?? false;

    if (!ok || !mounted) return;
    _keepBleOnDispose = true;
    _intentionalShutdown = true;
    _sessionClock.stop();
    _uiTimer?.cancel();
    _stopRecordSampleTimer();
    _softSyncWatchdog?.cancel();
    await _releaseRecordingSession(disconnectDevices: false);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: bgCream,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: primaryOrange),
              const SizedBox(height: 24),
              const Text('正在建立感測器連線',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 8),
              Text(_initStatus, style: const TextStyle(color: textLight)),
            ],
          ),
        ),
      );
    }

    final String currentSensorName = widget.sensors[_currentIndex]['part'];

    // [DEBUG] 顯示軟體同步狀態，確認穩定後可移除此 subtitle
    final String syncStatusLabel = switch (_phase) {
      _RecordingPhase.preparing =>
        '正在同步感測器…（${_firstPacketArrival.length}/${widget.sensors.length}）',
      _RecordingPhase.readyToStart => '同步完成，可開始測試',
      _RecordingPhase.resyncing =>
        '正在對齊感測器…（${_firstPacketArrival.length}/${widget.sensors.length}）',
      _RecordingPhase.recording => '錄製中…',
    };

    final double displaySeconds =
        _phase == _RecordingPhase.recording ? _elapsedSeconds : 0.0;

    return Stack(
      children: [
        Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: bgCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textDark, size: 20),
          onPressed: _isAnalyzing ? null : _confirmLeaveRecording,
        ),
        title: const Text('TUG 實時錄製',
          style: TextStyle(color: textDark, fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              displaySeconds.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 64, fontWeight: FontWeight.bold,
                color: primaryOrange,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            syncStatusLabel,
            style: TextStyle(
              color: _phase == _RecordingPhase.recording
                  ? Colors.green
                  : primaryOrange,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_phase == _RecordingPhase.readyToStart) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: accentGreen.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentGreen.withOpacity(0.8)),
                ),
                child: const Text(
                  '請受試者坐在椅子上，聽到開始後再執行 TUG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
          if (_masterSensorIndex != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '時間基準：${widget.sensors[_masterSensorIndex!]['part']}（Master）',
                style: const TextStyle(fontSize: 12, color: textLight),
              ),
            ),
          // [DEBUG] 各感測器偏移量顯示，確認穩定後刪除此 Padding 區塊
          const SizedBox(height: 16),
          // 感測器切換列
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: textDark),
                  onPressed: () => setState(() {
                    _currentIndex = (_currentIndex - 1) % 5;
                    if (_currentIndex < 0) _currentIndex = 4;
                  }),
                ),
                Text(currentSensorName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark)),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: textDark),
                  onPressed: () => setState(() => _currentIndex = (_currentIndex + 1) % 5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _buildChartCard('加速度計 (m/s²)', _accData[_currentIndex], -20, 20),
                const SizedBox(height: 16),
                _buildChartCard('陀螺儀 (deg/s)', _gyroData[_currentIndex], -200, 200),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: _buildBottomActionButton(),
          ),
        ],
      ),
    ),
        if (_isAnalyzing)
          Container(
            color: Colors.black.withOpacity(0.35),
            alignment: Alignment.center,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: primaryOrange),
                  SizedBox(height: 24),
                  Text(
                    '正在進行步態特徵分析…',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '請稍候，模型正在處理資料',
                    style: TextStyle(fontSize: 14, color: textLight),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomActionButton() {
    if (_phase == _RecordingPhase.readyToStart) {
      return InkWell(
        onTap: _disconnectDialogShown ? null : _onUserStartFormalTest,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primaryOrange,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryOrange.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Text(
            '開始即時測試',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }

    if (_phase == _RecordingPhase.recording) {
      return InkWell(
        onTap: (_disconnectDialogShown || _isAnalyzing) ? null : _finishTest,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.red[400],
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Text(
            '結束測試並分析',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _phase == _RecordingPhase.resyncing ? '正在對齊，請稍候…' : '等待感測器同步…',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  double _latestSpotTimeSec(List<List<FlSpot>> data) {
    double latest = 0.0;
    for (final series in data) {
      if (series.isNotEmpty) latest = max(latest, series.last.x);
    }
    return latest;
  }

  Widget _buildChartCard(String title, List<List<FlSpot>> data, double minY, double maxY) {
    final double latestT = _latestSpotTimeSec(data);
    final double anchor = _phase == _RecordingPhase.recording
        ? max(_elapsedSeconds, latestT)
        : latestT;
    final double maxX = max(_windowSize, anchor);
    final double minX = max(0.0, maxX - _windowSize);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textLight)),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: LineChart(LineChartData(
              minX: minX, maxX: maxX, minY: minY, maxY: maxY,
              lineBarsData: [
                _createLine(data[0], Colors.orange),
                _createLine(data[1], Colors.blue),
                _createLine(data[2], Colors.green),
              ],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                      style: const TextStyle(fontSize: 10, color: textLight)),
                  ),
                ),
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true, drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.grey[200], strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
            )),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: Colors.orange, label: 'X 軸'),
              SizedBox(width: 16),
              _LegendItem(color: Colors.blue, label: 'Y 軸'),
              SizedBox(width: 16),
              _LegendItem(color: Colors.green, label: 'Z 軸'),
            ],
          ),
        ],
      ),
    );
  }

  LineChartBarData _createLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots, isCurved: true, color: color,
      barWidth: 2, isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
    );
  }
}

// ─── 輔助 Widget ──────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: textDark)),
      ],
    );
  }
}

// ─── 資料模型 ─────────────────────────────────────────────────────────────────
//
// 移除硬體同步後，syncControl 與 syncAck 特徵值不再需要，
// _SensorRuntimeChannels 只保留量測相關欄位。
//