// استيراد المكتبات اللازمة
import 'package:shared_preferences/shared_preferences.dart'; // مكتبة لتخزين البيانات محليًا
import 'package:uuid/uuid.dart'; // مكتبة لتوليد UUID

// تعريف كلاس DeviceService لتوفير خدمات متعلقة بالجهاز
class DeviceService {
  static const _key = 'unique_device_id'; // المفتاح المستخدم لتخزين UUID في SharedPreferences
  static final Uuid _uuid = Uuid(); // كائن لتوليد UUID

  // دالة للحصول على UUID الفريد للجهاز
  static Future<String> getUniqueId() async {
    try {
      // الحصول على كائن SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // محاولة استرجاع UUID المخزن
      String? uniqueId = prefs.getString(_key);

      // إذا لم يكن UUID موجودًا، يتم توليد UUID جديد وتخزينه
      if (uniqueId == null) {
        uniqueId = _generateUUID(); // توليد UUID جديد
        await prefs.setString(_key, uniqueId); // تخزين UUID في SharedPreferences
        print('تم توليد وحفظ UUID: $uniqueId'); // طباعة رسالة عند الحفظ
      }

      // طباعة UUID المستخدم وإرجاعه
      print('UUID المستخدم: $uniqueId');
      return uniqueId;
    } catch (e) {
      // في حالة حدوث خطأ، يتم طباعة رسالة الخطأ وإرجاع قيمة افتراضية
      print('خطأ في الحصول على UUID: $e');
      return 'unknown'; // قيمة افتراضية في حالة الخطأ
    }
  }

  // دالة لتوليد UUID جديد
  static String _generateUUID() {
    return _uuid.v4(); // توليد UUID باستخدام الإصدار الرابع (v4)
  }
}