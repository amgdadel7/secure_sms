// استيراد المكتبات اللازمة
import 'package:flutter/material.dart'; // مكتبة لإنشاء واجهات المستخدم
import 'package:country_picker/country_picker.dart'; // مكتبة لاختيار الدول والحصول على معلوماتها

// تعريف كلاس CountryCodeUtils لتوفير أدوات مساعدة تتعلق برموز الدول
class CountryCodeUtils {
  // دالة للحصول على رمز الهاتف الخاص بالدولة بناءً على رمز الدولة (ISO)
  static String getPhoneCode(String countryCode) {
    // محاولة تحليل رمز الدولة باستخدام مكتبة country_picker
    // إذا تم العثور على الدولة، يتم إرجاع رمز الهاتف الخاص بها، وإلا يتم إرجاع القيمة الافتراضية '20'
    return Country.tryParse(countryCode)?.phoneCode ?? '20';
  }

  // دالة للحصول على صورة العلم الخاص بالدولة بناءً على رمز الدولة (ISO)
  static Widget getFlagImage(String countryCode) {
    return Image.asset(
      'flags/${countryCode.toLowerCase()}.png', // مسار صورة العلم (يتم تحويل رمز الدولة إلى أحرف صغيرة)
      width: 32, // عرض الصورة
      height: 32, // ارتفاع الصورة
      package: 'country_picker', // تحديد الحزمة التي تحتوي على الصور
    );
  }
}