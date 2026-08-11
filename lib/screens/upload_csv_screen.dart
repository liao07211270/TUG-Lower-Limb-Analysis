import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../tug_analysis_pipeline2.dart';
import 'analysis_screen.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';

// === 定義主題色 ===
const Color bgCream = Color(0xFFF9F2EF);
const Color primaryOrange = Color(0xFFF98C53);
const Color accentGreen = Color(0xFFD2E0AA);
const Color textDark = Color(0xFF2D3142);

class UploadCsvScreen extends StatefulWidget {
  final int userId;

  const UploadCsvScreen({super.key, required this.userId});

  @override
  State<UploadCsvScreen> createState() => _UploadCsvScreenState();
}

class _UploadCsvScreenState extends State<UploadCsvScreen> {
  String? _fileName;
  String? _filePath;
  String? _errorMessage;

  bool _isAnalyzing = false;
  double _analysisProgress = 0.0;
  Timer? _progressTimer;

  final TugAnalysisPipeline2 _pipeline = TugAnalysisPipeline2();

  // 🌟 新增：覆寫 initState，在畫面載入時順便把 AI 大腦叫起床
  @override
  void initState() {
    super.initState();
    _pipeline.initModel();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _errorMessage = null;
      _analysisProgress = 0.0;
    });
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (!mounted) return;
    if (result != null) {
      final pickedFile = result.files.single;
      final path = pickedFile.path;
      final name = pickedFile.name;
      if (path == null || path.isEmpty) {
        setState(() => _errorMessage = '無法取得檔案路徑，請將 CSV 下載到本機後再重新選取。');
        return;
      }
      if (!name.toLowerCase().endsWith('.csv')) {
        setState(() => _errorMessage = '格式錯誤：請上傳 .csv 結尾的檔案');
        return;
      }
      setState(() {
        _fileName = name;
        _filePath = path;
      });
    }
  }

  Future<void> _startAnalysis() async {
    if (_filePath == null) return;
    setState(() {
      _isAnalyzing = true;
      _analysisProgress = 0.0;
      _errorMessage = null;
    });

    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        if (_analysisProgress < 0.9) _analysisProgress += 0.02;
      });
    });

    try {
      File file = File(_filePath!);
      final input = file.openRead();
      final fields =
          await input
              .transform(utf8.decoder)
              .transform(const CsvToListConverter(eol: '\n'))
              .toList();

      // 🌟 關鍵 1：呼叫我們寫好的總指揮官，執行你同學的所有邏輯！
      TugResult result = await _pipeline.runAnalysis(fields);

      _progressTimer?.cancel();
      if (mounted) setState(() => _analysisProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 300));
      // 🌟 新增：準備存入資料庫的資料包
      // 這裡簡單用總時間判斷風險，你之後可以改成更專業的醫療邏輯
      String currentPhase =
          result.totalTime > 15.0
              ? '需要注意'
              : (result.totalTime > 12.0 ? '輕微波動' : '平穩');

      // 記得在檔案最上方 import 'package:intl/intl.dart'; 才能用 DateFormat 喔！
      String currentDate = DateFormat('yyyy年MM月dd日').format(DateTime.now());

      Map<String, dynamic> newRecord = {
        'date': currentDate,
        'total_time': result.totalTime,
        'stand_up': result.standUpTime,
        'walk_go': result.walkGoTime,
        'turn1': result.turn1Time,
        'walk_return': result.walkReturnTime,
        'turn2': result.turn2Time,
        'sit_down': result.sitDownTime,
        'phase': currentPhase,
        'user_id': widget.userId,
      };

      // 🌟 呼叫資料庫小幫手，把資料永久存起來！
      // 記得在檔案最上方 import 'database_helper.dart'; 喔！
      final int historyId = await DatabaseHelper.instance.insertHistory(
        newRecord,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => AnalysisDetailScreen(
                  totalTime: result.totalTime,
                  standUpTime: result.standUpTime,
                  walkGoTime: result.walkGoTime,
                  turn1Time: result.turn1Time,
                  walkReturnTime: result.walkReturnTime,
                  turn2Time: result.turn2Time,
                  sitDownTime: result.sitDownTime,
                  historyId: historyId,
                ),
          ),
        );
      }
    } catch (e) {
      _progressTimer?.cancel();
      if (mounted) {
        setState(() {
          _errorMessage = '分析時發生錯誤: $e';
          _isAnalyzing = false;
          _analysisProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgCream, // 奶油底色
      appBar: AppBar(
        backgroundColor: bgCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '上傳測試資料',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // === 純白圓潤的上傳區塊 ===
            GestureDetector(
              onTap: _isAnalyzing ? null : _pickFile,
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: _fileName != null ? accentGreen : Colors.transparent,
                    width: 2,
                  ), // 成功時顯示綠色邊框
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color:
                            _fileName != null
                                ? accentGreen.withOpacity(0.2)
                                : bgCream,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _fileName != null
                            ? Icons.check_circle_rounded
                            : Icons.cloud_upload_rounded,
                        size: 48,
                        color:
                            _fileName != null
                                ? Colors.green[700]
                                : primaryOrange,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _fileName ?? '點擊選擇 .csv 檔案',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: _fileName != null ? Colors.green[800] : textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 重新選擇檔案按鈕 (淺綠色)
            if (_fileName != null && !_isAnalyzing) ...[
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: _pickFile,
                  style: TextButton.styleFrom(
                    backgroundColor: accentGreen.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: Icon(Icons.sync, color: Colors.green[800]),
                  label: Text(
                    '重新選擇檔案',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 錯誤訊息顯示區
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const Spacer(),

            // 分析進度條 (橘色)
            if (_isAnalyzing) ...[
              Column(
                children: [
                  Text(
                    'AI 正在分析您的步態資料... ${(_analysisProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      color: primaryOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: _analysisProgress,
                      minHeight: 12,
                      backgroundColor: primaryOrange.withOpacity(0.2),
                      color: primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ],

            // 開始分析按鈕 (活力橘)
            if (!_isAnalyzing)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 5,
                  shadowColor: primaryOrange.withOpacity(0.5),
                  disabledBackgroundColor: Colors.white,
                  disabledForegroundColor: Colors.grey[400],
                ),
                onPressed: _fileName == null ? null : _startAnalysis,
                child: const Text(
                  '開始分析',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
