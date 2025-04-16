
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const _key = 'unique_device_id';
  static final Uuid _uuid = Uuid();

  static Future<String> getUniqueId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? uniqueId = prefs.getString(_key);

      if (uniqueId == null) {
        uniqueId = _generateUUID(); // توليد UUID جديد
        await prefs.setString(_key, uniqueId);
        print('تم توليد وحفظ UUID: $uniqueId');
      }

      print('UUID المستخدم: $uniqueId');
      return uniqueId;
    } catch (e) {
      print('خطأ في الحصول على UUID: $e');
      return 'unknown'; // قيمة افتراضية في حالة الخطأ
    }
  }

  static String _generateUUID() {
    return _uuid.v4(); // مثال: "550e8400-e29b-41d4-a716-446655440000"
  }
}