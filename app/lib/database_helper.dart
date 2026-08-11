import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class DatabaseHelper {
  // 建立一個單例 (Singleton)，確保整個 App 只有一個資料庫管家在運作
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // 取得資料庫的連線
  Future<Database> get database async {
    // 如果資料庫已經存在，就直接回傳
    if (_database != null) return _database!;
    // 如果不存在，就去手機裡建立一個新的
    _database = await _initDB('tug_gait_v2.db');
    return _database!;
  }

  // 初始化資料庫
  Future<Database> _initDB(String filePath) async {
    // 取得手機存放資料庫的預設路徑
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    print('🌟 我的資料庫在這裡：${await getDatabasesPath()}');

    // 打開資料庫，如果還沒有就執行 _createDB 來建立
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // === 建立資料表 (Table) ===
  Future _createDB(Database db, int version) async {
    // 建立一個名為 users 的表格
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        email TEXT UNIQUE, 
        password TEXT,
        name TEXT,
        age TEXT,
        height TEXT,
        weight TEXT,
        affectedArea TEXT
      )
    ''');
    // id: 自動遞增的使用者編號
    // email: 帳號 (UNIQUE 代表不能有重複的 Email 註冊)

    // 🌟 新增：建立歷史紀錄 (history) 表
    await db.execute('''
      CREATE TABLE history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        total_time REAL,
        stand_up REAL,
        walk_go REAL,
        turn1 REAL,
        walk_return REAL,
        turn2 REAL,
        sit_down REAL,
        phase TEXT,
        imu_series_path TEXT,
        user_id INTEGER
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (!await _tableExists(db, 'history')) {
      await db.execute('''
        CREATE TABLE history(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT,
          total_time REAL,
          stand_up REAL,
          walk_go REAL,
          turn1 REAL,
          walk_return REAL,
          turn2 REAL,
          sit_down REAL,
          phase TEXT,
          imu_series_path TEXT,
          user_id INTEGER
        )
      ''');
      return;
    }

    if (oldVersion < 2) {
      await _addColumnIfMissing(db, 'history', 'imu_series_path', 'TEXT');
    }
    if (oldVersion < 3) {
      await _addColumnIfMissing(db, 'history', 'user_id', 'INTEGER');
    }
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );
    return rows.isNotEmpty;
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String tableName,
    String columnName,
    String columnType,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final exists = columns.any((column) => column['name'] == columnName);
    if (!exists) {
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnName $columnType',
      );
    }
  }

  // 🔒 密碼雜湊函數 (把明文密碼變成 64 字元的亂碼)
  String hashPassword(String password) {
    var bytes = utf8.encode(password); // 步驟一：把密碼轉成電腦看的懂的位元組
    var digest = sha256.convert(bytes); // 步驟二：丟進 SHA-256 果汁機打碎
    return digest.toString(); // 步驟三：回傳打碎後的亂碼
  }
  // ==========================================
  // 下面是給 App 呼叫的功能：註冊、登入、檢查帳號
  // ==========================================

  // 1. 檢查 Email 是否已經被註冊過
  Future<bool> isEmailRegistered(String email) async {
    final db = await instance.database;
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    return result.isNotEmpty; // 如果有找到資料，回傳 true (已註冊)
  }

  // 2. 註冊：將新使用者資料存入資料庫
  // 新增使用者 (註冊)
  Future<int> registerUser(Map<String, dynamic> user) async {
    final db = await instance.database;

    // 🔒 關鍵在這裡！在存進資料庫前，把 user 裡面的密碼拿出來打碎，再塞回去
    user['password'] = hashPassword(user['password']);

    // 接著才存入資料庫
    return await db.insert('users', user);
  }

  // 3. 登入：檢查 Email 跟密碼是否正確
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    final db = await instance.database;
    // 去 users 表格搜尋這組帳號，並將輸入的密碼「打碎」後再去比對
    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      // 🔒 只有這裡修改了！加上 hashPassword 把密碼轉換成亂碼
      whereArgs: [email, hashPassword(password)],
    );

    if (result.isNotEmpty) {
      return result.first; // 登入成功，把使用者的資料回傳給 App
    } else {
      return null; // 找不到，回傳 null 代表登入失敗
    }
  }

  // 🔒 重設密碼 (更新資料庫內使用者的密碼)
  Future<int> updatePassword(String email, String newPassword) async {
    final db = await instance.database;
    String hashedNewPassword = hashPassword(newPassword);

    // 🌟 把更新的結果存進 count 變數
    int count = await db.update(
      'users',
      {'password': hashedNewPassword},
      where: 'email = ?',
      whereArgs: [email],
    );

    // 🌟 印出來檢查！
    print('💡 密碼更新成功！新的雜湊值為：$hashedNewPassword');
    print('💡 資料庫中有 $count 筆帳號被更新了！');

    return count;
  }

  // 4. 更新會員資料
  Future<int> updateUser(Map<String, dynamic> user) async {
    final db = await instance.database;
    return await db.update(
      'users',
      user,
      where: 'email = ?', // 靠 email 來認人
      whereArgs: [user['email']],
    );
  }

  // 存入一筆新紀錄
  Future<int> insertHistory(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('history', row);
  }

  // 撈出所有歷史紀錄 (用 id 遞減排序，最新的在最上面)
  Future<List<Map<String, dynamic>>> getAllHistory() async {
    Database db = await instance.database;
    return await db.query('history', orderBy: 'id DESC');
  }

  /// 僅該會員的紀錄（訪客未登入者不應呼叫；未帶 user_id 的舊資料不會出現）
  Future<List<Map<String, dynamic>>> getHistoryForUser(int userId) async {
    final db = await instance.database;
    return await db.query(
      'history',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
  }

  Future<Map<String, dynamic>?> getHistoryById(int id) async {
    final db = await instance.database;
    final rows = await db.query(
      'history',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int> updateHistoryImuPath(int id, String path) async {
    final db = await instance.database;
    return await db.update(
      'history',
      {'imu_series_path': path},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 刪除指定的歷史紀錄
  Future<int> deleteHistory(int id) async {
    Database db = await instance.database;
    return await db.delete('history', where: 'id = ?', whereArgs: [id]);
  }
}
