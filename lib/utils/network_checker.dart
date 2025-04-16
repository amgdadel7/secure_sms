// استيراد مكتبة dart:io للتعامل مع الشبكة والاتصال بالإنترنت
import 'dart:io';

// دالة للتحقق من وجود اتصال بالإنترنت
Future<bool> hasInternetConnection() async {
  try {
    // محاولة البحث عن عنوان IP الخاص بـ google.com
    final result = await InternetAddress.lookup('google.com');

    // إذا كانت النتيجة تحتوي على بيانات وعنوان IP غير فارغ، فهذا يعني وجود اتصال بالإنترنت
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      print("✅ Device is connected to the internet"); // طباعة رسالة تأكيد الاتصال
      return true; // إرجاع true للدلالة على وجود اتصال
    }
  } on SocketException catch (_) {
    // في حالة حدوث خطأ من نوع SocketException (مثل عدم وجود اتصال)
    print("❌ No internet connection"); // طباعة رسالة عدم وجود اتصال
    return false; // إرجاع false للدلالة على عدم وجود اتصال
  }

  // إرجاع false كقيمة افتراضية إذا لم يتم التحقق من الاتصال
  return false;
}