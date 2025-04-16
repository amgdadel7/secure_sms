// استيراد المكتبات اللازمة
import 'package:flutter/src/widgets/framework.dart'; // لإنشاء واجهات المستخدم
import 'package:provider/provider.dart'; // لإدارة الحالة باستخدام Provider
import 'package:untitled14/services/api_service.dart'; // استيراد خدمة API للتعامل مع الخادم

import '../services/device_service.dart'; // استيراد خدمة الجهاز للحصول على UUID
import '../services/location_service.dart'; // استيراد خدمة الموقع (غير مستخدمة هنا)
import 'package:sqflite/sqflite.dart'; // للتعامل مع قواعد البيانات SQLite
import 'package:path/path.dart'; // لإنشاء مسارات الملفات

import 'first_launch_manager.dart'; // استيراد مدير الإطلاق الأول

// تعريف كلاس RegistrationController لإدارة عملية التسجيل
class RegistrationController {
  // تعريف كائن لخدمة قاعدة البيانات المحلية
  static final LocalDatabaseService _localDb = LocalDatabaseService();

  // دالة لمعالجة عملية التسجيل
  static Future<void> handleRegistration({
    required String countryCode, // رمز الدولة
    required String phoneNumber, // رقم الهاتف
    required Function(String) onError, // دالة لمعالجة الأخطاء
    required BuildContext context, // السياق الحالي للتطبيق
  }) async {
    try {
      // الحصول على UUID الخاص بالجهاز
      final uuid = await DeviceService.getUniqueId();

      // تشغيل العمليات بالتوازي باستخدام Future.wait
      final sendFuture = ApiService.sendDeviceInfo(
        uuid: uuid, // إرسال UUID
        code: countryCode, // إرسال رمز الدولة
        phoneNum: phoneNumber, // إرسال رقم الهاتف
      );

      final localDbFuture = _localDb.upsertDeviceInfo(
        uuid: uuid, // تخزين UUID في قاعدة البيانات المحلية
        code: countryCode, // تخزين رمز الدولة
        phoneNum: phoneNumber, // تخزين رقم الهاتف
      );

      // انتظار نتيجة إرسال البيانات إلى الخادم
      final success = await sendFuture;
      if (!success) throw Exception('فشل إرسال البيانات إلى الخادم'); // إذا فشل الإرسال، يتم رمي استثناء

      // انتظار تخزين البيانات في قاعدة البيانات المحلية
      await localDbFuture;

      // إكمال عملية التسجيل باستخدام FirstLaunchManager
      await Provider.of<FirstLaunchManager>(context, listen: false)
          .completeRegistration();

    } catch (e) {
      // معالجة الأخطاء وإرسال رسالة الخطأ إلى دالة onError
      onError('⚠️ خطأ: ${e.toString()}');
    }
  }
}

// تعريف كلاس LocalDatabaseService لإدارة قاعدة البيانات المحلية
class LocalDatabaseService {
  static const _databaseName = 'local_device.db'; // اسم قاعدة البيانات
  static const _databaseVersion = 1; // إصدار قاعدة البيانات

  static Database? _database; // كائن قاعدة البيانات

  // دالة للحصول على قاعدة البيانات (تهيئتها إذا لم تكن موجودة)
  Future<Database> get database async {
    if (_database != null) return _database!; // إذا كانت قاعدة البيانات مهيأة، يتم إرجاعها
    _database = await _initDatabase(); // تهيئة قاعدة البيانات
    return _database!;
  }

  // دالة لتهيئة قاعدة البيانات
  Future<Database> _initDatabase() async {
    if (_database != null) return _database!; // إذا كانت قاعدة البيانات مهيأة، يتم إرجاعها
    final path = join(await getDatabasesPath(), _databaseName); // تحديد مسار قاعدة البيانات
    _database = await openDatabase(
      path,
      version: _databaseVersion, // تحديد إصدار قاعدة البيانات
      onCreate: _onCreate, // استدعاء دالة إنشاء الجداول
    );
    return _database!;
  }

  // دالة لإنشاء جدول قاعدة البيانات
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS device_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT, // معرف تلقائي
        uuid TEXT UNIQUE NOT NULL, // UUID فريد وغير فارغ
        code TEXT NOT NULL, // رمز الدولة
        phone_num TEXT UNIQUE NOT NULL, // رقم الهاتف فريد وغير فارغ
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP // تاريخ الإنشاء
      )
    ''');
    print('تم إنشاء جدول SQLite المحلي'); // طباعة رسالة عند إنشاء الجدول
  }

  // دالة لجلب UUID من قاعدة البيانات
  Future<String?> getUuid() async {
    final db = await database; // الحصول على قاعدة البيانات
    List<Map> result = await db.query('device_info', columns: ['uuid'], limit: 1); // استعلام لجلب UUID
    return result.isNotEmpty ? result.first['uuid'] as String : null; // إرجاع UUID إذا كان موجودًا
  }

  // دالة لجلب معلومات الجهاز (UUID ورقم الهاتف)
  Future<Map<String, String>?> getDeviceInfo() async {
    final db = await database; // الحصول على قاعدة البيانات
    List<Map> result = await db.query(
      'device_info',
      columns: ['uuid', 'phone_num'], // الأعمدة المطلوبة
      limit: 1, // تحديد عدد النتائج
    );
    if (result.isNotEmpty) {
      return {
        'uuid': result.first['uuid'] as String, // إرجاع UUID
        'phone_num': result.first['phone_num'] as String, // إرجاع رقم الهاتف
      };
    }
    return null; // إرجاع null إذا لم تكن هناك بيانات
  }

  // دالة لإدخال أو تحديث معلومات الجهاز في قاعدة البيانات
  Future<void> upsertDeviceInfo({
    required String uuid, // UUID
    required String code, // رمز الدولة
    required String phoneNum, // رقم الهاتف
  }) async {
    final db = await database; // الحصول على قاعدة البيانات
    await db.rawInsert('''
    INSERT OR REPLACE INTO device_info 
    (uuid, code, phone_num) 
    VALUES (?, ?, ?)
  ''', [uuid, code, phoneNum]); // إدخال أو تحديث البيانات
  }
}