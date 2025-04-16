// استيراد المكتبات اللازمة
import 'package:encrypt/encrypt.dart' as encrypt; // مكتبة للتشفير وفك التشفير
import 'package:sqflite/sqflite.dart'; // مكتبة للتعامل مع قواعد البيانات SQLite
import 'package:path/path.dart'; // مكتبة لإنشاء مسارات الملفات

// تعريف كلاس LocalKeyManager لإدارة المفاتيح المشتركة محليًا
class LocalKeyManager {
  static final _iv = encrypt.IV.fromLength(16); // تهيئة متجه التهيئة (IV) بطول 16 بايت
  static const _encryptionKey = 'your-32-byte-encryption-key'; // مفتاح التشفير (يجب أن يكون بطول 32 بايت)

  // دالة لتهيئة قاعدة البيانات
  static Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'local_keys.db'); // تحديد مسار قاعدة البيانات
    return openDatabase(
      path,
      version: 1, // إصدار قاعدة البيانات
      onCreate: (db, version) async {
        // إنشاء جدول لتخزين المفاتيح المشتركة
        await db.execute('''
          CREATE TABLE shared_secrets (
            id INTEGER PRIMARY KEY AUTOINCREMENT, // معرف تلقائي
            partner_uuid TEXT NOT NULL, // UUID الخاص بالطرف الآخر
            partner_phone TEXT NOT NULL, // رقم هاتف الطرف الآخر
            shared_secret TEXT NOT NULL, // المفتاح المشترك (مشفر)
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP // تاريخ الإنشاء
          )
        ''');
      },
    );
  }

  // دالة لحفظ المفتاح المشترك في قاعدة البيانات
  static Future<void> saveSharedSecret({
    required String partnerUUID, // UUID الخاص بالطرف الآخر
    required String partnerPhone, // رقم هاتف الطرف الآخر
    required String sharedSecret, // المفتاح المشترك
  }) async {
    final db = await _initDatabase(); // تهيئة قاعدة البيانات

    // تشفير المفتاح المشترك قبل التخزين
    final encrypter = encrypt.Encrypter(
        encrypt.AES(encrypt.Key.fromUtf8(_encryptionKey)) // استخدام AES للتشفير
    );

    final encryptedSecret = encrypter.encrypt(sharedSecret, iv: _iv).base64; // تشفير المفتاح وتحويله إلى Base64

    // إدخال البيانات المشفرة في قاعدة البيانات
    await db.insert('shared_secrets', {
      'partner_uuid': partnerUUID, // UUID الخاص بالطرف الآخر
      'partner_phone': partnerPhone, // رقم هاتف الطرف الآخر
      'shared_secret': encryptedSecret, // المفتاح المشفر
    });
  }

  // دالة لاسترجاع المفتاح المشترك من قاعدة البيانات
  static Future<String?> getSharedSecret(String partnerUUID) async {
    final db = await _initDatabase(); // تهيئة قاعدة البيانات
    final result = await db.query(
      'shared_secrets', // اسم الجدول
      where: 'partner_uuid = ?', // شرط البحث
      whereArgs: [partnerUUID], // قيمة البحث
    );

    if (result.isEmpty) return null; // إذا لم يتم العثور على المفتاح، يتم إرجاع null

    // فك تشفير المفتاح المشفر
    final encrypter = encrypt.Encrypter(
        encrypt.AES(encrypt.Key.fromUtf8(_encryptionKey)) // استخدام AES لفك التشفير
    );

    return encrypter.decrypt(
        encrypt.Encrypted.fromBase64(result.first['shared_secret'] as String), // فك التشفير من Base64
        iv: _iv // استخدام متجه التهيئة نفسه
    );
  }
}