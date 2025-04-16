// تعريف كلاس Validators لتوفير أدوات التحقق من صحة البيانات
class Validators {
  // دالة للتحقق من صحة رقم الهاتف
  static String? validatePhoneNumber(String? value) {
    // إذا كانت القيمة فارغة أو null، يتم إرجاع رسالة "Required"
    if (value == null || value.isEmpty) return 'Required';

    // التحقق من أن القيمة تحتوي فقط على أرقام ويتراوح طولها بين 9 و15 رقمًا
    if (!RegExp(r'^[0-9]{9,15}$').hasMatch(value)) {
      return 'Invalid phone number'; // إرجاع رسالة "Invalid phone number" إذا لم تتحقق الشروط
    }

    // إذا كانت القيمة صحيحة، يتم إرجاع null (لا توجد أخطاء)
    return null;
  }
}