import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../database_helper.dart';

const Color bgCream = Color(0xFFF9F2EF);
const Color primaryOrange = Color(0xFFF98C53);
const Color accentGreen = Color(0xFFD2E0AA);
const Color accentPeach = Color(0xFFFCCEB4);
const Color textDark = Color(0xFF2D3142);

class ProfileScreen extends StatefulWidget {
  final bool isGuest;
  final Map<String, dynamic>? userData;

  const ProfileScreen({super.key, this.isGuest = false, this.userData});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 狀態變數
  late String _email;
  late String _name;
  late String _age;
  late String _height;
  late String _weight;
  late String _affectedArea;

  @override
  void initState() {
    super.initState();
    // 初始化時，把資料庫傳來的資料塞進變數裡
    _email = widget.userData?['email'] ?? '';
    _name = widget.userData?['name'] ?? '未提供名稱';
    _age = widget.userData?['age'] ?? '-';
    _height = widget.userData?['height'] ?? '-';
    _weight = widget.userData?['weight'] ?? '-';
    _affectedArea = widget.userData?['affectedArea'] ?? '無';
  }

  void _showEditBottomSheet() {
    // === 修正 1：如果原本是預設值，編輯框就顯示空白，強迫填寫 ===
    final nameCtrl = TextEditingController(text: _name == '未提供名稱' ? '' : _name);
    final ageCtrl = TextEditingController(text: _age == '-' ? '' : _age);
    final heightCtrl = TextEditingController(
      text: _height == '-' ? '' : _height,
    );
    final weightCtrl = TextEditingController(
      text: _weight == '-' ? '' : _weight,
    );
    String tempAffectedArea = _affectedArea;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  color: bgCream,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '編輯個人資料',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- 姓名 (必填) ---
                      _buildLightTextField(
                        controller: nameCtrl,
                        labelText: '姓名 *', // 加上星號提示必填
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            // --- 年齡 (必填) ---
                            child: _buildLightTextField(
                              controller: ageCtrl,
                              labelText: '年齡 *', // 加上星號提示必填
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            // --- 身高 (改為選填) ---
                            child: _buildLightTextField(
                              controller: heightCtrl,
                              labelText: '身高 (選填)', // 標註選填
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // --- 體重 (改為選填) ---
                      _buildLightTextField(
                        controller: weightCtrl,
                        labelText: '體重 (選填)', // 標註選填
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: tempAffectedArea,
                        decoration: InputDecoration(
                          labelText: '患部',
                          labelStyle: const TextStyle(color: Colors.grey),
                          fillColor: Colors.white,
                          filled: true,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: primaryOrange,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: primaryOrange,
                        ),
                        items:
                            ['右膝', '左膝', '雙膝', '無']
                                .map(
                                  (String value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value,
                                      style: const TextStyle(color: textDark),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (newValue) {
                          if (newValue != null)
                            setModalState(() => tempAffectedArea = newValue);
                        },
                      ),

                      const SizedBox(height: 32),

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
                        ),
                        onPressed: () async {
                          // 1. 取得去空白後的文字
                          String name = nameCtrl.text.trim();
                          String age = ageCtrl.text.trim();
                          String height = heightCtrl.text.trim();
                          String weight = weightCtrl.text.trim();

                          // === 修正 2：確實阻擋空值 ===
                          if (name.isEmpty || age.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('姓名與年齡是必填項目喔！'),
                                backgroundColor: Colors.redAccent,
                                behavior:
                                    SnackBarBehavior.floating, // 讓提示框浮動更明顯
                              ),
                            );
                            return; // 確實中斷
                          }

                          // 2. 打包資料 (身高體重如果是空的，就存空字串)
                          Map<String, dynamic> updatedUser = {
                            'email': _email,
                            'password': widget.userData?['password'],
                            'name': name,
                            'age': age,
                            'height': height,
                            'weight': weight,
                            'affectedArea': tempAffectedArea,
                          };

                          await DatabaseHelper.instance.updateUser(updatedUser);

                          // 3. 更新畫面狀態
                          setState(() {
                            _name = name;
                            _age = age;
                            // === 修正 3：如果選填沒填，畫面預設顯示 '-'，避免出現奇怪的 ' cm' ===
                            _height = height.isEmpty ? '-' : height;
                            _weight = weight.isEmpty ? '-' : weight;
                            _affectedArea = tempAffectedArea;

                            if (widget.userData != null) {
                              widget.userData!['name'] = _name;
                              widget.userData!['age'] = _age;
                              widget.userData!['height'] = _height;
                              widget.userData!['weight'] = _weight;
                              widget.userData!['affectedArea'] = _affectedArea;
                            }
                          });

                          if (!context.mounted) return;
                          Navigator.pop(context); // 關閉彈窗
                        },
                        child: const Text(
                          '儲存變更',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: bgCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '個人資料',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body:
          widget.isGuest ? _buildGuestView(context) : _buildMemberView(context),
    );
  }

  Widget _buildMemberView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: accentPeach,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: primaryOrange.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: accentGreen.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '一般會員',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 40),

          Container(
            padding: const EdgeInsets.all(24.0),
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
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '基本資料',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    GestureDetector(
                      onTap: _showEditBottomSheet,
                      child: const Text(
                        '編輯',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryOrange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.cake_outlined, '年齡', '$_age 歲'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: bgCream, thickness: 1.5),
                ),
                _buildInfoRow(
                  Icons.height,
                  '身高（選填）',
                  _height == '-' ? '-' : '$_height cm',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: bgCream, thickness: 1.5),
                ),
                _buildInfoRow(
                  Icons.monitor_weight_outlined,
                  '體重(選填)',
                  _weight == '-' ? '-' : '$_weight kg',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: bgCream, thickness: 1.5),
                ),
                // ⚠️ 這裡改成了直接顯示「患部」
                _buildInfoRow(
                  Icons.personal_injury_outlined,
                  '患部',
                  _affectedArea,
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.red[100]!, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: Colors.white,
              ),
              onPressed:
                  () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  ),
              child: const Text(
                '登出',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              Icons.account_circle_outlined,
              size: 80,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            '您目前為訪客身分',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '訪客僅能進行 TUG 測試與查看單次分析結果。\n\n登入或註冊會員即可解鎖「歷史紀錄儲存」與「長期步態追蹤」功能！',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.6),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 5,
                shadowColor: primaryOrange.withOpacity(0.5),
              ),
              onPressed:
                  () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  ),
              child: const Text(
                '登入 / 註冊會員',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: primaryOrange.withOpacity(0.7), size: 24),
        const SizedBox(width: 16),
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildLightTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: textDark),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.grey),
        fillColor: Colors.white,
        filled: true,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primaryOrange, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
      ),
    );
  }
}
