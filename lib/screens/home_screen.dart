import 'dart:async';

import 'package:flutter/material.dart';
import 'history_screen.dart' show HistoryScreen, buildPhaseTimelineSingleBar;
import '../database_helper.dart';

// 引入其他頁面
import 'profile_screen.dart';
import 'upload_csv_screen.dart';
import 'device_connection_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;
  final Map<String, dynamic>? userData; // 接收資料

  const HomeScreen({super.key, this.isGuest = false, this.userData});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 1;

  // Expandable FAB 變數
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  bool _isMenuOpen = false;

  // 🌟 動態資料變數
  Map<String, dynamic>? _latestRecord;
  bool _isLoadingLatest = true;

  // === 統一的圖片主題色 ===
  final Color bgCream = const Color(0xFFF9F2EF);
  final Color primaryOrange = const Color(0xFFF98C53);
  final Color accentGreen = const Color(0xFFD2E0AA);
  final Color accentBlue = const Color(0xFFABD7FB);
  final Color accentPeach = const Color(0xFFFCCEB4);
  final Color textDark = const Color(0xFF2D3142);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
    );

    // 🌟 畫面初始化時載入最新紀錄
    _loadLatestData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 🌟 讀取最新一筆歷史紀錄
  Future<void> _loadLatestData() async {
    if (widget.isGuest) {
      setState(() => _isLoadingLatest = false);
      return;
    }

    final uid = widget.userData?['id'];
    if (uid == null) {
      if (mounted) {
        setState(() {
          _isLoadingLatest = false;
          _latestRecord = null;
        });
      }
      return;
    }
    final data = await DatabaseHelper.instance.getHistoryForUser(uid as int);
    if (mounted) {
      setState(() {
        if (data.isNotEmpty) {
          _latestRecord = data.first; // 拿最新的那一筆
        } else {
          _latestRecord = null;
        }
        _isLoadingLatest = false;
      });
    }
  }

  void _toggleMenu() {
    if (_isMenuOpen) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
    setState(() => _isMenuOpen = !_isMenuOpen);
  }

  /// 全螢幕開啟設備頁，避免底部導覽誤觸導致狀態重置。
  Future<void> _openDeviceConnectionFullscreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder:
            (context) => DeviceConnectionScreen(
              isGuest: widget.isGuest,
              userId: widget.userData?['id'] as int?,
            ),
      ),
    );
    if (mounted) _loadLatestData();
  }

  // === 訪客鎖定畫面 ===
  Widget _buildGuestLockedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: accentPeach.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline, size: 60, color: primaryOrange),
            ),
            const SizedBox(height: 24),
            Text(
              '訪客無法查看歷史紀錄',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '此區域僅限會員使用。\n註冊或登入即可儲存並追蹤長期的步態變化！',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 獨立出動態產生「最新測試動態」的卡片
  Widget _buildLatestTestCard() {
    if (_isLoadingLatest) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF98C53)),
      );
    }

    if (_latestRecord == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '目前尚未有測試紀錄',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    final total = (_latestRecord!['total_time'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近一次 TUG 測試',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                total.toStringAsFixed(2), // 🌟 動態總時間
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: primaryOrange,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '秒',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          buildPhaseTimelineSingleBar(Map<String, dynamic>.from(_latestRecord!)),
        ],
      ),
    );
  }

  // === 全新主頁 UI ===
  Widget _buildMainTestPage() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // 頂部：問候語與頭像
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '你好,',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isGuest ? '訪客' : (widget.userData?['name'] ?? '使用者'),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ProfileScreen(
                            isGuest: widget.isGuest,
                            userData: widget.userData,
                          ),
                    ),
                  );
                  setState(() {});
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accentPeach,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // 訪客判斷
          widget.isGuest
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Text(
                    '目前為訪客模式\n登入或註冊帳號即可儲存並查看專屬的 TUG 測試紀錄',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      height: 1.5,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '最新測試動態',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 🌟 呼叫會動態載入的卡片
                  _buildLatestTestCard(),
                ],
              ),

          const SizedBox(height: 100), // 給 FAB 留空間
        ],
      ),
    );
  }

  // === 懸浮按鈕 ===
  Widget _buildExpandableFab() {
    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          right: 16,
          bottom: _isMenuOpen ? 144 : 16,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _isMenuOpen ? 1.0 : 0.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '上傳檔案',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 16),
                ScaleTransition(
                  scale: _expandAnimation,
                  child: FloatingActionButton(
                    mini: true,
                    heroTag: 'upload_file',
                    backgroundColor: Colors.white,
                    foregroundColor: accentGreen,
                    elevation: 3,
                    onPressed: () async {
                      _toggleMenu();
                      final uid = widget.userData?['id'];
                      if (widget.isGuest || uid == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('請先登入會員以上傳紀錄')),
                        );
                        return;
                      }
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  UploadCsvScreen(userId: uid as int),
                        ),
                      );
                      _loadLatestData();
                    },
                    child: const Icon(Icons.upload_file),
                  ),
                ),
              ],
            ),
          ),
        ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          right: 16,
          bottom: _isMenuOpen ? 80 : 16,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _isMenuOpen ? 1.0 : 0.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '即時測試',
                  style: TextStyle(
                    color: textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 16),
                ScaleTransition(
                  scale: _expandAnimation,
                  child: FloatingActionButton(
                    mini: true,
                    heroTag: 'test_btn',
                    backgroundColor: Colors.white,
                    foregroundColor: accentBlue,
                    elevation: 3,
                    onPressed: () async {
                      _toggleMenu();
                      await _openDeviceConnectionFullscreen();
                    },
                    child: const Icon(Icons.bluetooth),
                  ),
                ),
              ],
            ),
          ),
        ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'main_add',
            onPressed: _toggleMenu,
            backgroundColor: primaryOrange,
            shape: const CircleBorder(),
            elevation: 4,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder:
                  (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
              child: Icon(
                _isMenuOpen ? Icons.close_rounded : Icons.play_arrow_rounded,
                key: ValueKey<bool>(_isMenuOpen),
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      widget.isGuest
          ? _buildGuestLockedScreen()
          : HistoryScreen(userId: widget.userData!['id'] as int),
      _buildMainTestPage(),
    ];

    return Scaffold(
      backgroundColor: bgCream,
      body: Stack(
        children: [
          pages[_currentIndex],
          if (_isMenuOpen)
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(color: bgCream.withOpacity(0.85)),
            ),
          _buildExpandableFab(),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: Colors.white,
        elevation: 10,
        selectedItemColor: primaryOrange,
        unselectedItemColor: Colors.grey[400],
        showSelectedLabels: true,
        showUnselectedLabels: false,
        onTap: (index) {
          if (index == 2) {
            unawaited(_openDeviceConnectionFullscreen());
            return;
          }
          setState(() => _currentIndex = index);
          if (index == 1) {
            _loadLatestData();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: '紀錄',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '主頁'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_bluetooth_rounded),
            label: '設備',
          ),
        ],
      ),
    );
  }
}
