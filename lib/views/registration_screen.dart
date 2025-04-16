// استيراد المكتبات اللازمة
import 'package:flutter/material.dart'; // لإنشاء واجهات المستخدم
import 'package:flutter/services.dart'; // للتعامل مع خدمات النظام
import 'package:provider/provider.dart'; // لإدارة الحالة باستخدام Provider
import 'package:geolocator/geolocator.dart'; // للوصول إلى خدمات الموقع
import 'package:untitled14/utils/country_code_utils.dart'; // أدوات لمعالجة رموز الدول
import 'package:untitled14/utils/validators.dart'; // أدوات للتحقق من صحة المدخلات
import '../widgets/country_picker_field.dart'; // ويدجت لاختيار الدولة
import '../controllers/registration_controller.dart'; // وحدة التحكم بالتسجيل
import '../services/location_service.dart'; // خدمة الموقع
import '../controllers/first_launch_manager.dart'; // إدارة الإطلاق الأول للتطبيق

// تعريف واجهة شاشة التسجيل
class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>(); // مفتاح النموذج للتحقق من صحة المدخلات
  final _phoneController = TextEditingController(); // وحدة التحكم بحقل رقم الهاتف
  String _countryCode = 'EG'; // رمز الدولة الافتراضي
  bool _isLoading = false; // حالة التحميل
  late AnimationController _animationController; // وحدة التحكم بالأنيميشن
  late Animation<double> _opacityAnimation; // أنيميشن لتغيير الشفافية

  @override
  void initState() {
    super.initState();
    _requestLocationPermission(); // طلب صلاحيات الموقع
    _setupAnimations(); // إعداد الأنيميشن
    _autoDetectCountry(); // الكشف التلقائي عن الدولة
  }

  // إعداد الأنيميشن
  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this, // توفير vsync للأنيميشن
      duration: Duration(seconds: 2), // مدة الأنيميشن
    );
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController, // وحدة التحكم بالأنيميشن
        curve: Curves.easeInOut, // منحنى الأنيميشن
      ),
    );
    _animationController.forward(); // بدء الأنيميشن
  }

  // طلب صلاحيات الموقع
  Future<void> _requestLocationPermission() async {
    final status = await Geolocator.checkPermission(); // التحقق من حالة الصلاحيات
    if (status == LocationPermission.denied) {
      await Geolocator.requestPermission(); // طلب الصلاحيات إذا كانت مرفوضة
    }
  }

  // الكشف التلقائي عن الدولة باستخدام GPS
  Future<void> _autoDetectCountry() async {
    final code = await LocationService.getCountryCodeByGPS(); // الحصول على رمز الدولة
    if (code != null && mounted) {
      setState(() => _countryCode = code); // تحديث رمز الدولة
    }
  }

  // معالجة إرسال النموذج
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return; // التحقق من صحة المدخلات

    setState(() => _isLoading = true); // تفعيل حالة التحميل
    _animationController.reverse(); // عكس الأنيميشن

    try {
      // استدعاء دالة التسجيل
      await RegistrationController.handleRegistration(
        countryCode: '+${CountryCodeUtils.getPhoneCode(_countryCode)}', // رمز الدولة
        phoneNumber: _phoneController.text, // رقم الهاتف
        context: context, // تمرير السياق
        onError: (error) => _showErrorDialog(error), // عرض رسالة خطأ عند الفشل
      );

      // إكمال عملية التسجيل
      await Provider.of<FirstLaunchManager>(context, listen: false)
          .completeRegistration();

      // الانتقال إلى الشاشة الرئيسية
      Navigator.pushReplacementNamed(context, '/home');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // إيقاف حالة التحميل
        _animationController.forward(); // إعادة تشغيل الأنيميشن
      }
    }
  }

  // عرض رسالة خطأ
  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error Occurred'), // عنوان الرسالة
        content: Text(error), // محتوى الرسالة
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), // إغلاق الرسالة
            child: Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose(); // التخلص من وحدة التحكم بالأنيميشن
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _animationController, // استخدام الأنيميشن
        builder: (context, child) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, // بداية التدرج
              end: Alignment.bottomCenter, // نهاية التدرج
              colors: [Colors.blue.shade800, Colors.blue.shade400], // ألوان التدرج
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(32), // مسافة داخلية
            child: FadeTransition(
              opacity: _opacityAnimation, // تطبيق الأنيميشن
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // محاذاة العناصر في المنتصف
                children: [
                  _buildFormCard(), // بناء بطاقة النموذج
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // بناء بطاقة النموذج
  Widget _buildFormCard() {
    return Card(
      elevation: 10, // ارتفاع الظل
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), // زوايا دائرية
      ),
      child: Padding(
        padding: EdgeInsets.all(24), // مسافة داخلية
        child: Form(
          key: _formKey, // مفتاح النموذج
          child: Column(
            children: [
              Text(
                'Get Started', // عنوان النموذج
                style: TextStyle(
                  fontSize: 28, // حجم النص
                  fontWeight: FontWeight.bold, // وزن النص
                  color: Colors.blue.shade800, // لون النص
                ),
              ),
              SizedBox(height: 30), // مسافة عمودية
              CountryPickerField(
                countryCode: _countryCode, // رمز الدولة الحالي
                onCountrySelected: (country) => setState(() {
                  _countryCode = country.countryCode; // تحديث رمز الدولة عند التحديد
                }),
              ),
              SizedBox(height: 20), // مسافة عمودية
              TextFormField(
                controller: _phoneController, // وحدة التحكم بحقل النص
                keyboardType: TextInputType.phone, // نوع لوحة المفاتيح
                style: TextStyle(fontSize: 16), // تنسيق النص
                decoration: InputDecoration(
                  labelText: 'Phone Number', // نص الإرشاد
                  prefix: Text(
                    '+${CountryCodeUtils.getPhoneCode(_countryCode)} ', // رمز الدولة
                    style: TextStyle(fontWeight: FontWeight.bold), // وزن النص
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), // زوايا دائرية
                  ),
                ),
                validator: (value) => Validators.validatePhoneNumber(value), // التحقق من صحة الرقم
              ),
              SizedBox(height: 30), // مسافة عمودية
              _buildSubmitButton(), // زر الإرسال
            ],
          ),
        ),
      ),
    );
  }

  // بناء زر الإرسال
  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300), // مدة الأنيميشن
      width: _isLoading ? 60 : 200, // عرض الزر بناءً على حالة التحميل
      height: 50, // ارتفاع الزر
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400], // ألوان التدرج
        ),
        borderRadius: BorderRadius.circular(_isLoading ? 30 : 10), // زوايا دائرية
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3), // لون الظل
            blurRadius: 10, // درجة التمويه
            offset: Offset(0, 5), // إزاحة الظل
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit, // تعطيل الزر أثناء التحميل
        style: ElevatedButton.styleFrom(
          primary: Colors.transparent, // لون الخلفية شفاف
          shadowColor: Colors.transparent, // لون الظل شفاف
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_isLoading ? 30 : 10), // زوايا دائرية
          ),
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white) // مؤشر تحميل
            : Text(
                'Start Now', // نص الزر
                style: TextStyle(
                  fontSize: 18, // حجم النص
                  fontWeight: FontWeight.bold, // وزن النص
                  color: Colors.white, // لون النص
                ),
              ),
      ),
    );
  }
}