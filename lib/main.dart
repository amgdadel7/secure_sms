// استيراد المكتبات اللازمة
import 'package:flutter/material.dart'; // لإنشاء واجهات المستخدم
import 'package:permission_handler/permission_handler.dart'; // مكتبة لإدارة الأذونات
import 'package:provider/provider.dart'; // مكتبة لإدارة الحالة باستخدام Provider
import 'controllers/first_launch_manager.dart'; // وحدة التحكم بالإطلاق الأول
import 'controllers/message_controller.dart'; // وحدة التحكم بالرسائل
import 'views/conversations_screen.dart'; // شاشة المحادثات
import 'views/registration_screen.dart'; // شاشة التسجيل

// دالة لفتح إعدادات التطبيق لتمكين الأذونات
void _showPermissionDialog() async {
  await openAppSettings(); // فتح إعدادات التطبيق
}

// دالة لطلب الأذونات المطلوبة
Future<bool> _requestPermissions() async {
  final permissions = [
    Permission.contacts, // إذن الوصول إلى جهات الاتصال
    Permission.location, // إذن الوصول إلى الموقع
    Permission.phone, // إذن الوصول إلى الهاتف
    Permission.sms, // إذن الوصول إلى الرسائل النصية
  ];

  final results = await permissions.request(); // طلب الأذونات

  // التحقق من أن جميع الأذونات قد تم منحها
  return results.values.every((status) => status.isGranted);
}

// شاشة لعرض رسالة تطلب من المستخدم منح الأذونات
class PermissionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // محاذاة العناصر في المنتصف
          children: [
            Text('الرجاء منح الأذونات المطلوبة'), // رسالة للمستخدم
            ElevatedButton(
              onPressed: () => openAppSettings(), // فتح إعدادات التطبيق عند الضغط
              child: Text('فتح الإعدادات'), // نص الزر
            ),
          ],
        ),
      ),
    );
  }
}

// الدالة الرئيسية للتطبيق
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // التأكد من تهيئة التطبيق قبل تشغيله

  final permissionsGranted = await _requestPermissions(); // طلب الأذونات

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FirstLaunchManager()), // توفير وحدة التحكم بالإطلاق الأول
        ChangeNotifierProvider(create: (_) => MessageController()..initDatabases()), // توفير وحدة التحكم بالرسائل وتهيئة قواعد البيانات
      ],
      child: MyApp(permissionsGranted: permissionsGranted), // تمرير حالة الأذونات إلى التطبيق
    ),
  );
}

// تعريف التطبيق الرئيسي
class MyApp extends StatelessWidget {
  final bool permissionsGranted; // حالة الأذونات

  const MyApp({Key? key, required this.permissionsGranted}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: permissionsGranted // التحقق من حالة الأذونات
          ? _buildMainScreen(context) // إذا كانت الأذونات ممنوحة، الانتقال إلى الشاشة الرئيسية
          : PermissionScreen(), // إذا لم تكن الأذونات ممنوحة، عرض شاشة طلب الأذونات
    );
  }

  // بناء الشاشة الرئيسية للتطبيق
  Widget _buildMainScreen(BuildContext context) {
    return Consumer<FirstLaunchManager>( // مراقبة حالة الإطلاق الأول
      builder: (context, launchManager, child) {
        return launchManager.isFirstLaunch // التحقق إذا كان الإطلاق الأول
            ? RegistrationScreen() // إذا كان الإطلاق الأول، عرض شاشة التسجيل
            : ConversationsScreen(); // إذا لم يكن الإطلاق الأول، عرض شاشة المحادثات
      },
    );
  }
}