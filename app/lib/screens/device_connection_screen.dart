import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../ble_session.dart';
import '../movella_device_mac.dart';
import 'recording_screen.dart';

// === 1. 全域主題配色 (奶油風) ===
const Color bgCream = Color(0xFFF9F2EF);
const Color primaryOrange = Color(0xFFF98C53);
const Color accentGreen = Color(0xFFD2E0AA);
const Color accentBlue = Color(0xFFABD7FB);
const Color accentPeach = Color(0xFFFCCEB4);
const Color textDark = Color(0xFF4A4A4A);
const Color textLight = Color(0xFF9E9E9E);

class DeviceConnectionScreen extends StatefulWidget {
  final bool isGuest;
  final int? userId;

  /// 嵌入於主頁時切換到底部「主頁」分頁；若獨立開啟路由可為 null。
  final VoidCallback? onNavigateHome;

  const DeviceConnectionScreen({
    super.key,
    this.isGuest = false,
    this.userId,
    this.onNavigateHome,
  });

  @override
  State<DeviceConnectionScreen> createState() => DeviceConnectionScreenState();
}

class DeviceConnectionScreenState extends State<DeviceConnectionScreen> {
  static final RegExp _macRegex = RegExp(
    r'([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})',
  );

  String? _normalizeMacOrNull(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final match = _macRegex.firstMatch(raw);
    if (match == null) return null;
    return match.group(0)!.replaceAll('-', ':').toUpperCase();
  }

  String? _extractMacFromDevice(BluetoothDevice device) {
    final fromRemoteId = _normalizeMacOrNull(device.remoteId.str);
    if (fromRemoteId != null) return fromRemoteId;
    final fromName = _normalizeMacOrNull(device.platformName);
    if (fromName != null) return fromName;
    return null;
  }

  // === 升級版：空插槽，準備接收真實設備 ===
  final List<Map<String, dynamic>> _sensors = [
    {
      'id': '1',
      'name': '等待綁定...',
      'deviceId': '尚未配對',
      'part': '腰部',
      'isConnected': false,
      'device': null,
      'mac': null,
    },
    {
      'id': '2',
      'name': '等待綁定...',
      'deviceId': '尚未配對',
      'part': '左大腿',
      'isConnected': false,
      'device': null,
      'mac': null,
    },
    {
      'id': '3',
      'name': '等待綁定...',
      'deviceId': '尚未配對',
      'part': '右大腿',
      'isConnected': false,
      'device': null,
      'mac': null,
    },
    {
      'id': '4',
      'name': '等待綁定...',
      'deviceId': '尚未配對',
      'part': '左小腿',
      'isConnected': false,
      'device': null,
      'mac': null,
    },
    {
      'id': '5',
      'name': '等待綁定...',
      'deviceId': '尚未配對',
      'part': '右小腿',
      'isConnected': false,
      'device': null,
      'mac': null,
    },
  ];

  int get _connectedCount =>
      _sensors.where((s) => s['isConnected'] == true).length;
  bool get _isAllConnected => _connectedCount == _sensors.length;

  StreamSubscription? _adapterStateSubscription;
  final List<StreamSubscription<BluetoothConnectionState>?>
      _deviceConnectionSubscriptions = List.filled(5, null);

  /// 使用者於前置對話框按下「確認」後才為 true，此時才啟動權限與掃描。
  bool _confirmedHardware = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreBindingsFromSessionIfAny();
      if (!mounted) return;
      if (_connectedCount > 0 &&
          BleSessionManager.instance.hasActiveSession) {
        setState(() => _confirmedHardware = true);
        return;
      }
      _showHardwareConfirmDialog();
    });
  }

  /// 從 [BleSessionManager] 還原綁定（測試結束返回後仍顯示已連線）。
  Future<void> _restoreBindingsFromSessionIfAny() async {
    if (!BleSessionManager.instance.hasActiveSession) return;
    final cached = BleSessionManager.instance.activeSensors;
    if (cached.isEmpty) return;

    await BleSessionManager.instance.syncSensorConnectionFlags(cached);

    for (final cachedSensor in cached) {
      final part = cachedSensor['part']?.toString();
      if (part == null) continue;
      final slot = _sensors.indexWhere((s) => s['part'] == part);
      if (slot < 0) continue;
      if (cachedSensor['device'] is BluetoothDevice) {
        _sensors[slot]['name'] = cachedSensor['name'] ?? _sensors[slot]['name'];
        _sensors[slot]['deviceId'] =
            cachedSensor['deviceId'] ?? _sensors[slot]['deviceId'];
        final device = cachedSensor['device'] as BluetoothDevice;
        _sensors[slot]['device'] = device;
        _sensors[slot]['mac'] = cachedSensor['mac'];
        _sensors[slot]['isConnected'] = cachedSensor['isConnected'] == true;
        if (_sensors[slot]['isConnected'] == true) {
          _watchDeviceConnection(slot, device);
        }
      }
    }

    BleSessionManager.instance.registerSensors(_sensors);
    if (mounted) setState(() {});
  }

  /// 前置確認：避免一進頁就觸發權限與藍牙掃描。
  void _showHardwareConfirmDialog() {
    if (!mounted || _confirmedHardware) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '使用前確認',
            style: TextStyle(color: textDark, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            '請確認您已配備 Movella 感測器',
            style: TextStyle(color: textDark, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (!mounted) return;
                setState(() => _confirmedHardware = true);
                _initAndAutoScan();
              },
              child: const Text(
                '確認',
                style: TextStyle(
                  color: primaryOrange,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    for (final sub in _deviceConnectionSubscriptions) {
      sub?.cancel();
    }
    super.dispose();
  }

  void _watchDeviceConnection(int index, BluetoothDevice device) {
    _deviceConnectionSubscriptions[index]?.cancel();
    _deviceConnectionSubscriptions[index] = device.connectionState.listen((
      state,
    ) {
      if (state != BluetoothConnectionState.disconnected || !mounted) return;
      final current = _sensors[index]['device'];
      if (current is BluetoothDevice && current.remoteId != device.remoteId) {
        return;
      }
      setState(() {
        _sensors[index]['isConnected'] = false;
        _sensors[index]['name'] = '等待綁定...';
        _sensors[index]['deviceId'] = '尚未配對';
        _sensors[index]['device'] = null;
        _sensors[index]['mac'] = null;
      });
      unawaited(BleSessionManager.instance.preserveSession(_sensors));
    });
  }

  // === 解決問題 2：監聽藍牙狀態並自動掃描 ===
  Future<void> _initAndAutoScan() async {
    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      if (defaultTargetPlatform == TargetPlatform.android)
        Permission.locationWhenInUse,
    ];
    final statuses = await permissions.request();

    final canScan = statuses[Permission.bluetoothScan]?.isGranted ?? true;
    final canConnect = statuses[Permission.bluetoothConnect]?.isGranted ?? true;

    if (canScan && canConnect) {
      // 監聽手機藍牙晶片狀態，確定「開啟」才下達掃描指令
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on) {
          unawaited(_safeStartScan());
        }
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請允許藍牙權限，才能掃描並連接感測器。')),
      );
    }
  }

  Future<void> _safeStartScan() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        debugPrint('BLE 掃描略過：adapter state=$state');
        return;
      }
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    } catch (e) {
      debugPrint('BLE 掃描失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BLE 掃描失敗，請確認藍牙與必要權限已開啟。')),
      );
    }
  }

  // === 核心功能：彈出掃描視窗並綁定 ===
  void _showBluetoothScannerBottomSheet(int sensorIndex) async {
    // 開啟選單時，確保正在掃描以獲取最新設備
    unawaited(_safeStartScan());

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        // 👇 加這一行，把外層（Scaffold 的）context 存起來
        final outerContext = this.context;
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: bgCream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Icon(Icons.bluetooth_searching, color: primaryOrange),
                    SizedBox(width: 12),
                    Text(
                      '請選擇要綁定的感測器',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: FlutterBluePlus.scanResults,
                  initialData: const [],
                  builder: (context, snapshot) {
                    // 過濾出包含 Movella 的設備
                    final results =
                        (snapshot.data ?? [])
                            .where(
                              (r) =>
                                  r.device.platformName.isNotEmpty &&
                                  r.device.platformName.contains('Movella'),
                            )
                            .toList();

                    if (results.isEmpty) {
                      return const Center(
                        child: Text(
                          '掃描中或附近無設備...\n(請確保感測器已開機且未連接官方 App)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textLight, height: 1.5),
                        ),
                      );
                    }

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final device = results[index].device;
                        // 檢查這顆感測器是否已被其他部位綁定
                        bool isAlreadyBound = _sensors.any(
                          (s) => s['deviceId'] == device.remoteId.str,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  isAlreadyBound
                                      ? Colors.grey[300]!
                                      : Colors.transparent,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.sensors,
                              color:
                                  isAlreadyBound ? Colors.grey : primaryOrange,
                            ),
                            title: Text(
                              device.platformName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isAlreadyBound ? Colors.grey : textDark,
                              ),
                            ),
                            subtitle: Text(
                              'ID: ${device.remoteId.str.substring(0, 13)}...',
                              style: TextStyle(
                                fontSize: 12,
                                color: isAlreadyBound ? Colors.grey : textLight,
                              ),
                            ),
                            trailing:
                                isAlreadyBound
                                    ? const Text(
                                      '已綁定',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    )
                                    : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accentGreen,
                                        elevation: 0,
                                      ),
                                      onPressed: () async {
                                        FlutterBluePlus.stopScan();

                                        // 1. ⚡ 立即關閉底部的「掃描清單選單」
                                        if (mounted) Navigator.pop(context);

                                        // 狀態控制變數
                                        bool isConnectionCancelled = false;

                                        // 2. 必須用外層頁面 context：bottom sheet 已 pop，其 builder 的 context 可能已失效。
                                        showDialog<void>(
                                          context: outerContext,
                                          barrierDismissible: false,
                                          builder: (_) {
                                            return _BleConnectWaitDialog(
                                              deviceName: device.platformName,
                                              onCancel: () async {
                                                isConnectionCancelled = true;
                                                await device.disconnect();
                                                if (!outerContext.mounted) {
                                                  return;
                                                }
                                                Navigator.of(
                                                  outerContext,
                                                  rootNavigator: true,
                                                ).pop();
                                              },
                                            );
                                          },
                                        );

                                        try {
                                          final session =
                                              BleSessionManager.instance;
                                          await session.clearSensorSlot(
                                            _sensors,
                                            sensorIndex,
                                            disconnectDevice: true,
                                          );

                                          // 🔗 3. 執行連線
                                          final connected = await session
                                              .connectSensorIfNeeded(device);
                                          if (!connected) {
                                            throw Exception('感測器連線逾時或已中斷');
                                          }

                                          if (isConnectionCancelled) return;

                                          // 🔍 4. 尋找服務
                                          final runtimeChannels = await session
                                              .discoverRuntimeChannels(
                                                sensorIndex,
                                                device,
                                              );
                                          if (runtimeChannels == null) {
                                            throw Exception('找不到量測服務或 Notify 通道');
                                          }

                                          if (isConnectionCancelled) return;

                                          // 5. 更新主畫面 UI 狀態
                                          final macFromCfg =
                                              await readMovellaDotIdentityMac(
                                                device,
                                              );
                                          final extractedMac =
                                              macFromCfg ??
                                              _extractMacFromDevice(device);
                                          setState(() {
                                            _sensors[sensorIndex]['isConnected'] =
                                                true;
                                            _sensors[sensorIndex]['name'] =
                                                device.platformName;
                                            _sensors[sensorIndex]['deviceId'] =
                                                device.remoteId.str;
                                            _sensors[sensorIndex]['device'] =
                                                device;
                                            _sensors[sensorIndex]['mac'] =
                                                extractedMac;
                                          });
                                          _watchDeviceConnection(
                                            sensorIndex,
                                            device,
                                          );

                                          // ✅ 強力關閉：確保關掉的是最上層的 Dialog
                                          if (outerContext.mounted &&
                                              !isConnectionCancelled) {
                                            // 使用 rootNavigator 確保 pop 的是 Dialog 而不是頁面
                                            Navigator.of(
                                              outerContext,
                                              rootNavigator: true,
                                            ).pop();
                                          }
                                        } catch (e) {
                                          // ❌ 發生錯誤時也要關閉轉圈圈（使用者已按取消時不要再 pop / 不要再噴 SnackBar）
                                          if (!outerContext.mounted ||
                                              isConnectionCancelled) {
                                            return;
                                          }
                                          Navigator.of(
                                            outerContext,
                                            rootNavigator: true,
                                          ).pop();
                                          ScaffoldMessenger.of(
                                            outerContext,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('連線失敗：$e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text(
                                        '綁定',
                                        style: TextStyle(
                                          color: textDark,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => FlutterBluePlus.stopScan());
  }

  Future<void> _disconnectSensor(int index) async {
    await _deviceConnectionSubscriptions[index]?.cancel();
    _deviceConnectionSubscriptions[index] = null;

    final disconnected = await BleSessionManager.instance.disconnectSensorAt(
      _sensors,
      index,
    );

    if (!disconnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_sensors[index]['part']} 斷線失敗，請確認感測器狀態後再試一次。'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    if (mounted) setState(() {});
  }

  /// 離開設備流程或切換分頁時由 [HomeScreen] 或返回鍵呼叫。
  Future<void> disconnectAllBoundDevices() async {
    await BleSessionManager.instance.endSession(clearUiBindings: true);
    if (mounted) setState(() {});
  }

  /// 返回上一頁但保留 BLE 連線（供測試後再次進入設備頁）。
  Future<void> _leaveScreenKeepingConnection() async {
    BleSessionManager.instance.registerSensors(_sensors);
    await BleSessionManager.instance.syncSensorConnectionFlags(_sensors);
    if (!mounted) return;
    if (widget.onNavigateHome != null) {
      widget.onNavigateHome!();
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _startSync() async {
    await BleSessionManager.instance.syncSensorConnectionFlags(_sensors);
    if (mounted) setState(() {});
    if (!_isAllConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('有感測器已斷線，請重新綁定所有感測器後再同步。'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    BleSessionManager.instance.registerSensors(_sensors);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '即將同步感測器，請稍候…',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 1),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TugRecordingScreen(
              sensors: _sensors,
              isGuest: widget.isGuest,
              userId: widget.userId,
            ),
      ),
    );

    await BleSessionManager.instance.preserveSession(_sensors);
    if (mounted) setState(() {});
  }

  /// 依實際 BLE 狀態更新列表上的連線顯示。
  Future<void> refreshConnectionUiFromDevices() async {
    await BleSessionManager.instance.syncSensorConnectionFlags(_sensors);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          unawaited(
            BleSessionManager.instance.preserveSession(_sensors),
          );
        }
      },
      child: Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: bgCream,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: primaryOrange.withOpacity(0.1), blurRadius: 4),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: textDark,
              size: 16,
            ),
          ),
          onPressed: () => unawaited(_leaveScreenKeepingConnection()),
        ),
        title: const Text(
          '設備管理',
          style: TextStyle(
            color: textDark,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: textLight),
            tooltip: '重新掃描與重置',
            onPressed: () async {
              unawaited(_safeStartScan());
              await disconnectAllBoundDevices();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildStatusHeader(),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: _sensors.length,
              itemBuilder:
                  (context, index) => _buildSensorCard(index, _sensors[index]),
            ),
          ),
          _buildBottomActionButton(),
        ],
      ),
    ),
    );
  }

  Widget _buildStatusHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: accentBlue.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Movella DOT 連線狀態',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textLight,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$_connectedCount',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color:
                            _isAllConnected ? Colors.green[600] : primaryOrange,
                      ),
                    ),
                    const Text(
                      ' / 5',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    _isAllConnected ? Colors.green.withOpacity(0.15) : bgCream,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isAllConnected
                    ? Icons.bluetooth_connected_rounded
                    : Icons.bluetooth_searching_rounded,
                size: 32,
                color: _isAllConnected ? Colors.green[700] : textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard(int index, Map<String, dynamic> sensor) {
    final bool isConnected = sensor['isConnected'];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isConnected ? Colors.green.withOpacity(0.4) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isConnected
                      ? Colors.green.withOpacity(0.1)
                      : accentPeach.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sensors_rounded,
              color: isConnected ? Colors.green[600] : primaryOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      sensor['part'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: bgCream,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sensor['name'],
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: textLight,
                          ),
                          overflow: TextOverflow.ellipsis, // 🌟 名字太長會自動變成 ...
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${sensor['deviceId'].toString().length > 15 ? '${sensor['deviceId'].toString().substring(0, 15)}...' : sensor['deviceId']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: textLight,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap:
                () =>
                    isConnected
                        ? _disconnectSensor(index)
                        : _showBluetoothScannerBottomSheet(index),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isConnected ? Colors.red[400] : bgCream,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                isConnected ? '取消連接' : '點擊綁定',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isConnected ? Colors.white : primaryOrange,
                ),
              ),
            ),
          ), // ← InkWell 結束
        ], // ← Row 的 children 結束
      ), // ← Row 結束
    ); // ← AnimatedContainer 結束
  }

  Widget _buildBottomActionButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: _isAllConnected ? _startSync : null,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _isAllConnected ? primaryOrange : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
              boxShadow:
                  _isAllConnected
                      ? [
                        BoxShadow(
                          color: primaryOrange.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                      : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isAllConnected
                      ? Icons.sync_rounded
                      : Icons.lock_outline_rounded,
                  color: _isAllConnected ? Colors.white : Colors.grey[400],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  _isAllConnected ? '同步感測器' : '請先綁定所有感測器',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _isAllConnected ? Colors.white : Colors.grey[400],
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 連線中轉圈：只在 [initState] 排一次 10 秒計時器，避免放在 [StatefulBuilder] 內每次 rebuild 重複排程。
class _BleConnectWaitDialog extends StatefulWidget {
  const _BleConnectWaitDialog({
    required this.deviceName,
    required this.onCancel,
  });

  final String deviceName;
  final Future<void> Function() onCancel;

  @override
  State<_BleConnectWaitDialog> createState() => _BleConnectWaitDialogState();
}

class _BleConnectWaitDialogState extends State<_BleConnectWaitDialog> {
  bool _showCancel = false;
  Timer? _showCancelTimer;

  @override
  void initState() {
    super.initState();
    _showCancelTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() => _showCancel = true);
    });
  }

  @override
  void dispose() {
    _showCancelTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: primaryOrange),
            const SizedBox(height: 24),
            Text(
              '正在連線至\n${widget.deviceName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textDark,
                height: 1.5,
              ),
            ),
            if (_showCancel) ...[
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  unawaited(widget.onCancel());
                },
                child: const Text(
                  '連線過久？點此取消',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
