// استيراد المكتبات اللازمة
import 'package:geolocator/geolocator.dart'; // مكتبة للحصول على الموقع الجغرافي
import 'package:geocoding/geocoding.dart'; // مكتبة لتحويل الإحداثيات إلى معلومات جغرافية

// تعريف كلاس LocationService لتوفير خدمات الموقع
class LocationService {
  // دالة للحصول على رمز الدولة باستخدام GPS
  static Future<String?> getCountryCodeByGPS() async {
    try {
      // التحقق من تفعيل خدمة الموقع
      final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) return null; // إذا كانت الخدمة غير مفعلة، يتم إرجاع null

      // الحصول على الإحداثيات الحالية
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high, // تحديد دقة عالية للموقع
      );

      // تحويل الإحداثيات إلى رمز الدولة
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, // خط العرض
        position.longitude, // خط الطول
      );

      if (placemarks.isEmpty) return null; // إذا لم يتم العثور على أي بيانات، يتم إرجاع null
      return placemarks.first.isoCountryCode; // إرجاع رمز الدولة (ISO)
    } catch (e) {
      // في حالة حدوث خطأ، يتم طباعة رسالة الخطأ وإرجاع null
      print("Error getting country code: $e");
      return null;
    }
  }
}