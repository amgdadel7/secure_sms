// استيراد المكتبات اللازمة
import 'dart:convert'; // مكتبة لتحويل البيانات بين JSON والنصوص
import 'package:http/http.dart' as http; // مكتبة لإجراء طلبات HTTP

// تعريف كلاس ApiService لتوفير خدمات الاتصال بالخادم
class ApiService {
  // عنوان URL الأساسي للخادم
  static const String _baseUrl = 'https://political-thoracic-spatula.glitch.me';

  // دالة لإرسال معلومات الجهاز إلى الخادم
  static Future<bool> sendDeviceInfo({
    required String uuid, // UUID الخاص بالجهاز
    required String code, // رمز الدولة
    required String phoneNum, // رقم الهاتف
  }) async {
    print("asdqwe${uuid}"); // طباعة UUID للتأكد من القيم المرسلة

    // إرسال طلب POST إلى الخادم
    final response = await http.post(
      Uri.parse('$_baseUrl/api/device-info'), // عنوان API لإرسال معلومات الجهاز
      headers: {'Content-Type': 'application/json'}, // تحديد نوع المحتوى كـ JSON
      body: jsonEncode({
        'uuid': uuid, // إرسال UUID
        'code': code, // إرسال رمز الدولة
        'phone_num': phoneNum, // إرسال رقم الهاتف
      }),
    );

    // إرجاع true إذا كان رمز الاستجابة 200 (نجاح)، وإلا false
    return response.statusCode == 200;
  }
}