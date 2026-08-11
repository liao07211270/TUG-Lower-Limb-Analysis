import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../database_helper.dart'; // 加上 ../ 代表回到上一層 lib 資料夾尋找// ⚠️ 引入我們剛剛寫好的資料庫管家

// === 定義主題色 ===
const Color bgCream = Color(0xFFF9F2EF);
const Color primaryOrange = Color(0xFFF98C53);
const Color textDark = Color(0xFF2D3142);

// --- 註冊頁面 (1)：建立帳號 ---
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _isLoading = false; // 控制是否正在檢查帳號

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateFields);
    _passwordController.addListener(_validateFields);
    _confirmPasswordController.addListener(_validateFields);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateFields() {
    setState(() {
      final email = _emailController.text;
      if (email.isNotEmpty &&
          !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _emailError = '請輸入有效的電子郵件格式';
      } else {
        _emailError = null;
      }

      final password = _passwordController.text;
      if (password.isNotEmpty &&
          !RegExp(
            r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d]{8,}$',
          ).hasMatch(password)) {
        _passwordError = '密碼格式不符合要求';
      } else {
        _passwordError = null;
      }

      final confirmPassword = _confirmPasswordController.text;
      if (confirmPassword.isNotEmpty && confirmPassword != password) {
        _confirmPasswordError = '與上方密碼不一致';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  bool get _isStep1Valid =>
      _emailController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _confirmPasswordController.text.isNotEmpty &&
      _emailError == null &&
      _passwordError == null &&
      _confirmPasswordError == null;

  // ⚠️ 新增：點擊下一步時的檢查邏輯
  void _handleNextStep() async {
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();

    // 呼叫管家：檢查 Email 是否已經註冊過
    bool isRegistered = await DatabaseHelper.instance.isEmailRegistered(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (isRegistered) {
      setState(() {
        _emailError = '此電子郵件已被註冊，請直接登入或換一個帳號';
      });
    } else {
      // 沒註冊過，帶著帳號密碼前往步驟二
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => PersonalInfoScreen(
                email: email,
                password: _passwordController.text, // 傳遞密碼
              ),
        ),
      );
    }
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
          '註冊帳戶',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '步驟 1 / 2',
              style: TextStyle(
                color: primaryOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '建立您的登入資訊',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 32),

            _buildLightTextField(
              controller: _emailController,
              labelText: '帳號 (電子郵件)',
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
            ),
            const SizedBox(height: 16),
            _buildLightTextField(
              controller: _passwordController,
              labelText: '密碼',
              obscureText: true,
              errorText: _passwordError,
              helperText: '大小寫英文和數字至少8位數',
            ),
            const SizedBox(height: 16),
            _buildLightTextField(
              controller: _confirmPasswordController,
              labelText: '確認密碼',
              obscureText: true,
              errorText: _confirmPasswordError,
            ),

            const SizedBox(height: 48),

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
              onPressed: _isStep1Valid ? _handleNextStep : null, // ⚠️ 改為呼叫檢查邏輯
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
                        '下一步',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 註冊頁面 (2)：填寫個人資料 ---
class PersonalInfoScreen extends StatefulWidget {
  final String email; // ⚠️ 接收步驟一傳來的帳號
  final String password; // ⚠️ 接收步驟一傳來的密碼

  const PersonalInfoScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String? _selectedAffectedArea;
  final List<String> _affectedAreas = ['右膝', '左膝', '雙膝', '無'];

  String? _ageError;
  String? _heightError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateFields);
    _ageController.addListener(_validateFields);
    _heightController.addListener(_validateFields);
    _weightController.addListener(_validateFields);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _validateFields() {
    setState(() {
      final ageText = _ageController.text;
      if (ageText.isNotEmpty) {
        final age = int.tryParse(ageText);
        _ageError =
            (age == null || age <= 0 || age > 110) ? '請輸入 1~110 之間的數字' : null;
      } else {
        _ageError = null;
      }

      final heightText = _heightController.text;
      if (heightText.isNotEmpty) {
        final height = double.tryParse(heightText);
        _heightError =
            (height == null || height < 100 || height > 250)
                ? '請輸入 100~250 之間的數字'
                : null;
      } else {
        _heightError = null;
      }
    });
  }

  bool get _isStep2Valid =>
      _nameController.text.isNotEmpty &&
      _ageController.text.isNotEmpty &&
      _heightController.text.isNotEmpty &&
      _weightController.text.isNotEmpty &&
      _selectedAffectedArea != null &&
      _ageError == null &&
      _heightError == null;

  // ⚠️ 新增：正式把資料存入手機資料庫
  void _completeRegistration() async {
    setState(() => _isLoading = true);

    // 打包所有資料成一個 Map
    Map<String, dynamic> newUser = {
      'email': widget.email,
      'password': widget.password,
      'name': _nameController.text.trim(),
      'age': _ageController.text.trim(),
      'height': _heightController.text.trim(),
      'weight': _weightController.text.trim(),
      'affectedArea': _selectedAffectedArea,
    };

    // 呼叫管家：把這包資料存入資料庫，並保留自動產生的使用者 id。
    final userId = await DatabaseHelper.instance.registerUser(newUser);

    if (!mounted) return;
    setState(() => _isLoading = false);

    // 註冊成功！跳轉到主畫面
    // ⚠️ 把 newUser 變成可修改的字典
    final modifiableUser = Map<String, dynamic>.from(newUser);
    modifiableUser['id'] = userId;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (context) => HomeScreen(isGuest: false, userData: modifiableUser),
      ),
      (route) => false,
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
          '填寫個人資料',
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '步驟 2 / 2',
              style: TextStyle(
                color: primaryOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '完善您的步態檔案',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 32),

            _buildLightTextField(controller: _nameController, labelText: '姓名'),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildLightTextField(
                    controller: _ageController,
                    labelText: '年齡',
                    keyboardType: TextInputType.number,
                    errorText: _ageError,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLightTextField(
                    controller: _heightController,
                    labelText: '身高 (cm)',
                    keyboardType: TextInputType.number,
                    errorText: _heightError,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLightTextField(
              controller: _weightController,
              labelText: '體重 (kg)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // 患部下拉選單
            LayoutBuilder(
              builder: (context, constraints) {
                return DropdownMenu<String>(
                  width: constraints.maxWidth,
                  initialSelection: _selectedAffectedArea,
                  label: const Text('患部', style: TextStyle(color: Colors.grey)),
                  textStyle: const TextStyle(fontSize: 16, color: textDark),
                  trailingIcon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: primaryOrange,
                  ),
                  selectedTrailingIcon: const Icon(
                    Icons.keyboard_arrow_up,
                    color: primaryOrange,
                  ),

                  menuStyle: MenuStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.white),
                    elevation: WidgetStateProperty.all(4),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),

                  inputDecorationTheme: InputDecorationTheme(
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

                  onSelected:
                      (newValue) =>
                          setState(() => _selectedAffectedArea = newValue),
                  dropdownMenuEntries:
                      _affectedAreas.map((String value) {
                        return DropdownMenuEntry<String>(
                          value: value,
                          label: value,
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color>((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.hovered) ||
                                      states.contains(WidgetState.pressed))
                                    return primaryOrange.withOpacity(0.15);
                                  return Colors.transparent;
                                }),
                            foregroundColor:
                                WidgetStateProperty.resolveWith<Color>((
                                  states,
                                ) {
                                  if (states.contains(WidgetState.hovered) ||
                                      states.contains(WidgetState.pressed))
                                    return primaryOrange;
                                  return textDark;
                                }),
                            overlayColor: WidgetStateProperty.all(
                              Colors.transparent,
                            ),
                          ),
                        );
                      }).toList(),
                );
              },
            ),

            const SizedBox(height: 48),

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
              onPressed:
                  _isStep2Valid
                      ? _completeRegistration
                      : null, // ⚠️ 改為呼叫寫入資料庫邏輯
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
                        '完成註冊並登入',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// === 柔和白底的 TextField 樣式 ===
Widget _buildLightTextField({
  required String labelText,
  bool obscureText = false,
  TextInputType? keyboardType,
  TextEditingController? controller,
  String? errorText,
  String? helperText,
}) {
  return TextField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    style: const TextStyle(color: textDark),
    decoration: InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.grey),
      errorText: errorText,
      helperText: helperText,
      helperMaxLines: 2,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    ),
  );
}
