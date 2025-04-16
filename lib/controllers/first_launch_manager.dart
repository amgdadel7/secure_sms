import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// هذا الكلاس مسؤول عن إدارة حالة الإطلاق الأول للتطبيق
// ويستخدم ChangeNotifier لإبلاغ واجهة المستخدم بأي تغييرات في الحالة
class FirstLaunchManager extends ChangeNotifier {
  // متغير خاص لتحديد ما إذا كانت هذه هي أول مرة يتم فيها فتح التطبيق
  bool _isFirstLaunch = true;

  // Getter لإرجاع قيمة حالة الإطلاق الأول
  bool get isFirstLaunch => _isFirstLaunch;

  // المُنشئ Constructor: يتم استدعاء الدالة الخاصة بتحميل حالة الإطلاق من SharedPreferences
  FirstLaunchManager() {
    _loadLaunchState();
  }

  // دالة خاصة لتحميل حالة الإطلاق الأول من التخزين المحلي (SharedPreferences)
  Future<void> _loadLaunchState() async {
    final prefs = await SharedPreferences.getInstance(); // الحصول على كائن SharedPreferences
    _isFirstLaunch = prefs.getBool('first_launch') ?? true; // إذا لم تكن القيمة موجودة، يتم اعتبارها أول إطلاق
    notifyListeners(); // إعلام المستمعين بأن هناك تغيير في الحالة
  }

  // دالة لتحديث الحالة عند اكتمال التسجيل
  Future<void> completeRegistration() async {
    final prefs = await SharedPreferences.getInstance(); // الحصول على SharedPreferences
    await prefs.setBool('first_launch', false); // حفظ أن التطبيق لم يعد في أول إطلاق
    _isFirstLaunch = false; // تحديث المتغير الداخلي
    notifyListeners(); // إعلام الواجهة بضرورة إعادة بناء نفسها بناءً على التغيير
  }
}
