// استيراد المكتبات اللازمة
import 'package:sqflite/sqflite.dart'; // مكتبة للتعامل مع قواعد البيانات SQLite
import 'package:path/path.dart'; // مكتبة لإنشاء مسارات الملفات

// تعريف كلاس DatabaseHelper لإدارة قاعدة البيانات
class DatabaseHelper {
  static Database? _database; // كائن قاعدة البيانات (يتم تهيئته عند الحاجة)

  // دالة للحصول على قاعدة البيانات (تهيئتها إذا لم تكن موجودة)
  Future<Database> get database async {
    if (_database != null) return _database!; // إذا كانت قاعدة البيانات مهيأة، يتم إرجاعها
    _database = await _initDatabase(); // تهيئة قاعدة البيانات
    return _database!;
  }

  // دالة لتهيئة قاعدة البيانات
  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'local_keys.db'); // تحديد مسار قاعدة البيانات
    return openDatabase(
      path,
      version: 2, // إصدار قاعدة البيانات
      onCreate: onCreate, // استدعاء دالة إنشاء الجداول عند الإنشاء
    );
  }

  // دالة لجلب المفتاح المشترك باستخدام UUID
  Future<BigInt?> getSharedSecret({
    required String senderUUID, // UUID الخاص بالمرسل
    required String receiverUUID, // UUID الخاص بالمستقبل
  }) async {
    final db = await database; // الحصول على قاعدة البيانات
    final List<Map<String, dynamic>> result = await db.query(
      'key_info', // اسم الجدول
      columns: ['sharedSecret'], // الأعمدة المطلوبة
      where: 'senderUUID = ? AND receiverUUID = ?', // شرط البحث
      whereArgs: [senderUUID, receiverUUID], // قيم البحث
    );
    print("filteredMessages1${result.first['sharedSecret']}"); // طباعة المفتاح المشترك
    return result.isNotEmpty
        ? BigInt.parse(result.first['sharedSecret'] as String) // إرجاع المفتاح إذا كان موجودًا
        : null; // إرجاع null إذا لم يكن موجودًا
  }

  // دالة لجلب المفتاح المشترك باستخدام أرقام الهواتف
  Future<BigInt?> getSharedSecret1({
    required String senderNUM, // رقم هاتف المرسل
    required String receiverNUM, // رقم هاتف المستقبل
  }) async {
    final db = await database; // الحصول على قاعدة البيانات
    final List<Map<String, dynamic>> result = await db.query(
      'key_info', // اسم الجدول
      columns: ['sharedSecret'], // الأعمدة المطلوبة
      where: 'senderNUM = ? AND receiverNUM = ?', // شرط البحث
      whereArgs: [senderNUM, receiverNUM], // قيم البحث
    );
    print("filteredMessages1${result.first['sharedSecret']}"); // طباعة المفتاح المشترك
    return result.isNotEmpty
        ? BigInt.parse(result.first['sharedSecret'] as String) // إرجاع المفتاح إذا كان موجودًا
        : null; // إرجاع null إذا لم يكن موجودًا
  }

  // دالة لجلب معلومات المفاتيح باستخدام أرقام الهواتف
  Future<List<Map<String, dynamic>>> fetchKeyInfoByNumbers({
    required String senderNUM, // رقم هاتف المرسل
    required String receiverNUM, // رقم هاتف المستقبل
  }) async {
    final db = await database; // الحصول على قاعدة البيانات
    final result = await db.query(
      'key_info', // اسم الجدول
      where: '(senderNUM = ? AND receiverNUM = ?) OR (senderNUM = ? AND receiverNUM = ?)', // شرط البحث
      whereArgs: [senderNUM, receiverNUM, receiverNUM, senderNUM], // قيم البحث
    );

    if (result.isNotEmpty) {
      print('✅ تم العثور على ${result.length} نتيجة'); // طباعة عدد النتائج إذا كانت موجودة
    } else {
      print('❌ لم يتم العثور على أي نتائج'); // طباعة رسالة إذا لم تكن هناك نتائج
    }

    return result; // إرجاع النتائج
  }

  // دالة لإنشاء جدول قاعدة البيانات
  Future<void> onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS key_info (
      id INTEGER PRIMARY KEY AUTOINCREMENT, // معرف تلقائي
      senderUUID TEXT NOT NULL, // UUID الخاص بالمرسل
      senderNUM TEXT, // رقم هاتف المرسل
      receiverUUID TEXT NOT NULL, // UUID الخاص بالمستقبل
      receiverNUM TEXT, // رقم هاتف المستقبل
      sharedSecret TEXT NOT NULL, // المفتاح المشترك
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, // تاريخ الإنشاء
      UNIQUE(senderUUID, receiverUUID) // ضمان عدم تكرار نفس الزوج من المرسل والمستقبل
    )
  ''');
    print('✅ تم إنشاء جدول key_info محلياً'); // طباعة رسالة عند إنشاء الجدول
  }

  // دالة لجلب UUID المستقبل باستخدام UUID المرسل ورقم المستقبل
  Future<String?> queryreceiverUUID({
    required String senderUUID, // UUID الخاص بالمرسل
    required String receiverNUM, // رقم هاتف المستقبل
  }) async {
    final db = await database; // الحصول على قاعدة البيانات
    final List<Map<String, dynamic>> getkey = await db.query(
      'key_info', // اسم الجدول
      where: 'senderNUM = ? AND receiverNUM = ?', // شرط البحث
      whereArgs: [senderUUID, receiverNUM], // قيم البحث
    );

    if (getkey.isEmpty) {
      print('⚠️ No keys found for senderUUID: $senderUUID and receiverNUM: $receiverNUM'); // طباعة رسالة إذا لم تكن هناك نتائج
      return null; // إرجاع null إذا لم تكن هناك نتائج
    }

    final receiverUUID = getkey[0]['receiverUUID'] as String?; // جلب UUID المستقبل
    return receiverUUID; // إرجاع UUID المستقبل
  }

  // دالة لجلب UUID المستقبل باستخدام أرقام الهواتف
  Future<String?> queryreceiverUUID_by_serderUUID({
    required String senderNUM, // رقم هاتف المرسل
    required String receiverNUM, // رقم هاتف المستقبل
  }) async {
    final db = await database; // الحصول على قاعدة البيانات
    final List<Map<String, dynamic>> results = await db.query(
      'key_info', // اسم الجدول
      where: 'senderNUM = ? AND receiverNUM = ?', // شرط البحث
      whereArgs: [senderNUM, receiverNUM], // قيم البحث
      limit: 1, // تحديد عدد النتائج
    );

    if (results.isEmpty) return null; // إرجاع null إذا لم تكن هناك نتائج

    final receiverUUID = results[0]['receiverUUID']?.toString(); // جلب UUID المستقبل
    return receiverUUID; // إرجاع UUID المستقبل
  }

  // دالة لتخزين المفاتيح محليًا
  Future<void> storeKeysLocally({
    required String senderUUID, // UUID الخاص بالمرسل
    required String senderNUM, // رقم هاتف المرسل
    required String? receiverUUID, // UUID الخاص بالمستقبل
    required String receiverNUM, // رقم هاتف المستقبل
    required BigInt sharedSecret, // المفتاح المشترك
  }) async {
    final db = await database; // الحصول على قاعدة البيانات

    // بناء شرط البحث للتأكد من عدم وجود المفتاح مسبقًا
    String whereClause = 'senderUUID = ? AND receiverUUID ${receiverUUID == null ? 'IS' : '='} ?';
    List<dynamic> whereArgs = [senderUUID, receiverUUID];

    final List<Map<String, dynamic>> existing = await db.query(
      'key_info', // اسم الجدول
      where: whereClause, // شرط البحث
      whereArgs: whereArgs, // قيم البحث
    );

    if (existing.isEmpty) {
      // إذا لم يكن المفتاح موجودًا، يتم إدخاله
      await db.insert(
        'key_info',
        {
          'senderUUID': senderUUID,
          'senderNUM': senderNUM,
          'receiverUUID': receiverUUID,
          'receiverNUM': receiverNUM,
          'sharedSecret': sharedSecret.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace, // استبدال البيانات إذا كانت موجودة
      );
      print('$sharedSecret 🔑 تم حفظ المفاتيح محلياً'); // طباعة رسالة عند الحفظ
    } else {
      print('المفاتيج موجودة مسبقاً'); // طباعة رسالة إذا كانت المفاتيح موجودة مسبقًا
    }
  }

  // دالة للتحقق من وجود الجدول
  Future<bool> tableExists(String tableName) async {
    final db = await database; // الحصول على قاعدة البيانات
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?", // استعلام للتحقق من وجود الجدول
      [tableName], // اسم الجدول
    );
    return result.isNotEmpty; // إرجاع true إذا كان الجدول موجودًا
  }
}