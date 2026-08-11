import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import '../database_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _obscurePassword = true;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _emailError;
  String? _passwordError;

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _formOpacityAnimation;

  final Color bgCream = const Color(0xFFF9F2EF);
  final Color primaryOrange = const Color(0xFFF98C53);
  final Color accentGreen = const Color.fromARGB(255, 167, 198, 80);
  final Color textDark = const Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _slideAnimation = Tween<double>(begin: 180.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _logoScaleAnimation = Tween<double>(begin: 1.6, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _formOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // === 彈窗 1：尚未註冊提示 ===
  void _showUnregisteredDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: bgCream,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: primaryOrange, size: 28),
                const SizedBox(width: 12),
                Text(
                  '帳號尚未註冊',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textDark,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            content: const Text(
              '該電子郵件尚未被註冊，是否立即前往註冊帳號？',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), // 點擊取消，關閉彈窗
                child: const Text(
                  '取消',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // 先關閉彈窗
                  // 跳轉到註冊頁面
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
                child: const Text(
                  '前往註冊',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  // === 彈窗 2：訪客權限說明 ===
  void _showGuestWarningDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: bgCream,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.info_outline, color: accentGreen, size: 28),
                const SizedBox(width: 12),
                Text(
                  '訪客登入須知',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textDark,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            content: const Text(
              '訪客僅能進行 TUG 測試與查看單次分析結果，無法使用「歷史紀錄儲存」等完整功能。\n\n確定要以訪客身分繼續嗎？',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), // 點擊取消，關閉彈窗
                child: const Text(
                  '取消',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGreen, // 訪客使用綠色按鈕
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // 先關閉彈窗
                  // 確認以訪客身分進入主畫面
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(isGuest: true),
                    ),
                  );
                },
                child: const Text(
                  '確定',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  // === 升級版登入驗證邏輯 ===
  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      if (email.isEmpty) {
        _emailError = '請輸入電子郵件';
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _emailError = '請輸入有效的電子郵件格式';
      } else {
        _emailError = null;
      }

      if (password.isEmpty) {
        _passwordError = '請輸入密碼';
      } else if (!RegExp(
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d]{8,}$',
      ).hasMatch(password)) {
        _passwordError = '密碼需包含大小寫英文及數字，且至少8碼';
      } else {
        _passwordError = null;
      }
    });

    if (_emailError == null && _passwordError == null) {
      setState(() => _isLoading = true);

      // ⚠️ 1. 先去資料庫檢查這個 Email 到底有沒有註冊過
      bool isRegistered = await DatabaseHelper.instance.isEmailRegistered(
        email,
      );

      if (!mounted) return;

      if (!isRegistered) {
        // 如果沒註冊，把轉圈圈關掉，跳出「前往註冊」的彈窗
        setState(() => _isLoading = false);
        _showUnregisteredDialog();
        return; // 提早結束，不往下查密碼了
      }

      // ⚠️ 2. 確定有註冊，才去比對密碼對不對
      final user = await DatabaseHelper.instance.loginUser(email, password);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        // 登入成功
        final modifiableUser = Map<String, dynamic>.from(user);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    HomeScreen(isGuest: false, userData: modifiableUser),
          ),
        );
      } else {
        // 帳號存在，但是密碼打錯了
        setState(() {
          _passwordError = '密碼錯誤，請重新輸入';
        });
      }
    }
  }

  InputDecoration _buildLightInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(prefixIcon, color: primaryOrange.withOpacity(0.7)),
      suffixIcon: suffixIcon,
      errorText: errorText,
      fillColor: Colors.white,
      filled: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: primaryOrange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 20),
    );
  }

  // === 忘記密碼：步驟一 (輸入並檢查信箱) ===
  void _showForgotPasswordStep1() {
    final resetEmailController = TextEditingController();
    bool isChecking = false;
    String? emailError; // 🌟 新增：用來控制紅字錯誤訊息

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: bgCream,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.all(24), // 增加內邊距
              title: Row(
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    color: primaryOrange,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '尋找您的帳號',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textDark,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9, // 🌟 強制加寬視窗
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '請輸入您註冊時使用的電子信箱。',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: resetEmailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: textDark),
                      // 🌟 直接套用你原本設計的精美輸入框（包含錯誤紅字支援）
                      decoration: _buildLightInputDecoration(
                        labelText: '註冊信箱',
                        prefixIcon: Icons.email_outlined,
                        errorText: emailError,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '取消',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      isChecking
                          ? null
                          : () async {
                            final email = resetEmailController.text.trim();

                            // 每次點擊先清空錯誤
                            setState(() => emailError = null);

                            if (email.isEmpty) {
                              setState(() => emailError = '請輸入電子信箱'); // 🌟 觸發紅字
                              return;
                            }

                            setState(() => isChecking = true);
                            bool isRegistered = await DatabaseHelper.instance
                                .isEmailRegistered(email);
                            if (!context.mounted) return;
                            setState(() => isChecking = false);

                            if (!isRegistered) {
                              setState(
                                () => emailError = '找不到此信箱，請確認是否輸入正確',
                              ); // 🌟 觸發紅字
                            } else {
                              Navigator.pop(context);
                              _showForgotPasswordStep2(email);
                            }
                          },
                  child:
                      isChecking
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            '下一步',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // === 忘記密碼：步驟二 (輸入並重設密碼) ===
  void _showForgotPasswordStep2(String validEmail) {
    final newPasswordController = TextEditingController();
    bool isUpdating = false;
    String? passwordError; // 🌟 新增：用來控制紅字錯誤訊息

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: bgCream,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.all(24),
              title: Row(
                children: [
                  Icon(Icons.lock_reset, color: primaryOrange, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    '設定新密碼',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textDark,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9, // 🌟 強制加寬視窗
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '正在為 $validEmail 重設密碼',
                      style: TextStyle(
                        color: primaryOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      style: TextStyle(color: textDark),
                      // 🌟 套用精美輸入框
                      decoration: _buildLightInputDecoration(
                        labelText: '新密碼 (至少8碼)',
                        prefixIcon: Icons.lock_outline,
                        errorText: passwordError,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '取消重設',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      isUpdating
                          ? null
                          : () async {
                            final newPassword = newPasswordController.text;

                            setState(() => passwordError = null);

                            if (!RegExp(
                              r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d]{8,}$',
                            ).hasMatch(newPassword)) {
                              setState(
                                () => passwordError = '密碼需包含大小寫英文及數字，且至少8碼',
                              ); // 🌟 觸發紅字
                              return;
                            }

                            setState(() => isUpdating = true);
                            await DatabaseHelper.instance.updatePassword(
                              validEmail,
                              newPassword,
                            );
                            if (!context.mounted) return;

                            Navigator.pop(context);
                            // 成功提示保留 SnackBar (因為彈窗已經關閉了)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('密碼重設成功！請使用新密碼登入。')),
                            );
                          },
                  child:
                      isUpdating
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            '確認重設',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                ),
              ],
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: Container(
                          height: 110,
                          width: 110,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryOrange.withOpacity(0.2),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.directions_walk_rounded,
                            size: 60,
                            color: primaryOrange,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Opacity(
                        opacity: _formOpacityAnimation.value,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '歡迎回來',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'TUG 步態測試評估系統',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 48),

                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(color: textDark),
                              decoration: _buildLightInputDecoration(
                                labelText: '帳號 (電子郵件)',
                                prefixIcon: Icons.email_outlined,
                                errorText: _emailError,
                              ),
                            ),
                            const SizedBox(height: 16),

                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: TextStyle(color: textDark),
                              decoration: _buildLightInputDecoration(
                                labelText: '密碼',
                                prefixIcon: Icons.lock_outline,
                                errorText: _passwordError,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.grey,
                                  ),
                                  onPressed:
                                      () => setState(
                                        () =>
                                            _obscurePassword =
                                                !_obscurePassword,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const RegisterScreen(),
                                        ),
                                      ),
                                  child: Text(
                                    '沒有帳號？註冊',
                                    style: TextStyle(
                                      color: primaryOrange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _showForgotPasswordStep1,
                                  child: Text(
                                    '忘記密碼',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                backgroundColor: primaryOrange,
                                foregroundColor: Colors.white,
                                elevation: 5,
                                shadowColor: primaryOrange.withOpacity(0.5),
                              ),
                              onPressed: _isLoading ? null : _handleLogin,
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        ),
                                      )
                                      : const Text(
                                        '登入',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                            ),
                            const SizedBox(height: 32),

                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey[300],
                                    thickness: 1,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    '或',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey[300],
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                side: BorderSide(color: accentGreen, width: 2),
                                foregroundColor: textDark,
                                backgroundColor: Colors.white,
                              ),
                              icon: Icon(
                                Icons.person_outline,
                                color: accentGreen,
                              ),
                              label: const Text(
                                '以訪客身分繼續',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: _showGuestWarningDialog, // ⚠️ 改為呼叫彈窗
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
