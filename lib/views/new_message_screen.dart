// استيراد المكتبات اللازمة
import 'package:flutter/material.dart'; // لإنشاء واجهات المستخدم
import 'package:fast_contacts/fast_contacts.dart'; // مكتبة للوصول إلى جهات الاتصال
import 'package:provider/provider.dart'; // مكتبة لإدارة الحالة باستخدام Provider
import '../controllers/message_controller.dart'; // وحدة التحكم بالرسائل
import 'chat_screen.dart'; // شاشة المحادثة

/// تعريف ثوابت الألوان لتطبيق اللون الرمادي المائل للزُرقة
class AppColors {
  static const scaffoldBackground = Color(0xFFE6EFF6); // لون خلفية الشاشة
  static const topBackground = Color(0xFFF2FBFF); // لون خلفية الشريط العلوي
  static const appBarText = Color(0xFF202124); // لون النص في شريط التطبيق
  static const appBarIcon = Color(0xFF202124); // لون الأيقونات في شريط التطبيق
  static const inputLabel = Color(0xFF5F6368); // لون نص الإرشاد
}

// تعريف واجهة شاشة الرسائل الجديدة
class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({Key? key}) : super(key: key);

  @override
  _NewMessageScreenState createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController _searchController = TextEditingController(); // وحدة التحكم بحقل البحث
  List<Contact> _contacts = []; // قائمة جهات الاتصال
  List<Contact> _filteredContacts = []; // قائمة جهات الاتصال بعد الفلترة
  String _searchQuery = ""; // نص البحث الحالي

  /// دالة لتوليد لون ثابت للـ Avatar بناءً على اسم جهة الاتصال
  Color _getAvatarBackgroundColor(String text) {
    if (text.isEmpty) return Colors.grey; // إذا كان النص فارغاً، يتم استخدام اللون الرمادي
    final int hash = text.codeUnits.fold(0, (prev, element) => prev + element); // حساب قيمة فريدة للنص
    return Colors.primaries[hash % Colors.primaries.length].shade400; // اختيار لون بناءً على القيمة
  }

  @override
  void initState() {
    super.initState();
    _loadContacts(); // تحميل جهات الاتصال عند بدء الشاشة
  }

  /// دالة لتحميل جهات الاتصال
  Future<void> _loadContacts() async {
    final contacts = await FastContacts.getAllContacts(); // جلب جميع جهات الاتصال
    setState(() {
      _contacts = contacts; // تخزين جهات الاتصال
      _filteredContacts = contacts; // تعيين القائمة المفلترة كنسخة من القائمة الأصلية
    });
  }

  /// فلترة جهات الاتصال وفق الاستعلام
  void _filterContacts(String query) {
    setState(() {
      _searchQuery = query; // تحديث نص البحث
      _filteredContacts = _contacts.where((contact) {
        final lowerQuery = query.toLowerCase(); // تحويل النص إلى أحرف صغيرة
        final name = contact.displayName.toLowerCase(); // تحويل اسم جهة الاتصال إلى أحرف صغيرة
        final phoneMatch = contact.phones.isNotEmpty &&
            contact.phones.any((phone) => phone.number.contains(query)); // التحقق من تطابق الرقم
        return name.contains(lowerQuery) || phoneMatch; // التحقق من تطابق الاسم أو الرقم
      }).toList();
    });
  }

  /// تطبيع رقم الهاتف للمقارنة الصحيحة
  String _normalizePhoneNumber(String phoneNumber) {
    String normalized = phoneNumber.replaceAll(RegExp(r'[^0-9]'), ''); // إزالة الأحرف غير الرقمية
    if (normalized.startsWith('00')) {
      normalized = normalized.substring(2); // إزالة "00" من البداية
    } else if (normalized.startsWith('0')) {
      normalized = normalized.substring(1); // إزالة "0" من البداية
    }
    return normalized;
  }

  /// التحقق من وجود محادثة مسبقًا مع العنوان المحدد
  Future<bool> _isConversationExists(String address) async {
    final messageController = Provider.of<MessageController>(context, listen: false); // الحصول على وحدة التحكم بالرسائل
    final conversations = await messageController.getConversations(); // جلب المحادثات
    String normalizedAddress = _normalizePhoneNumber(address); // تطبيع العنوان
    for (var key in conversations.keys) {
      if (_normalizePhoneNumber(key) == normalizedAddress) { // مقارنة العنوان مع المحادثات
        return true;
      }
    }
    return false;
  }

  /// الحصول على المفتاح المطابق للمحادثة إن وجد
  Future<String?> _getExistingConversationKey(String address) async {
    final messageController = Provider.of<MessageController>(context, listen: false); // الحصول على وحدة التحكم بالرسائل
    final conversations = await messageController.getConversations(); // جلب المحادثات
    String normalizedAddress = _normalizePhoneNumber(address); // تطبيع العنوان
    for (var key in conversations.keys) {
      if (_normalizePhoneNumber(key) == normalizedAddress) { // مقارنة العنوان مع المحادثات
        return key;
      }
    }
    return null;
  }

  /// تجميع جهات الاتصال حسب أول حرف من الاسم
  Map<String, List<Contact>> _groupContactsByInitial(List<Contact> contacts) {
    contacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase())); // ترتيب جهات الاتصال
    final Map<String, List<Contact>> grouped = {};
    for (var contact in contacts) {
      String firstLetter = contact.displayName.isNotEmpty
          ? contact.displayName[0].toUpperCase() // الحصول على الحرف الأول من الاسم
          : "#"; // إذا كان الاسم فارغاً
      if (!grouped.containsKey(firstLetter)) {
        grouped[firstLetter] = []; // إنشاء مجموعة جديدة إذا لم تكن موجودة
      }
      grouped[firstLetter]!.add(contact); // إضافة جهة الاتصال إلى المجموعة
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedContacts = _filteredContacts; // استخدام القائمة المفلترة

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground, // لون خلفية الشاشة
      appBar: AppBar(
        backgroundColor: AppColors.topBackground, // لون خلفية الشريط العلوي
        elevation: 0, // إزالة الظل
        title: const Text(
          "New conversation", // عنوان الشريط العلوي
          style: TextStyle(
            color: AppColors.appBarText, // لون النص
            fontWeight: FontWeight.w500, // وزن النص متوسط
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.appBarIcon), // لون الأيقونات
      ),
      body: Column(
        children: [
          // مربع البحث
          Container(
            color: AppColors.topBackground, // لون خلفية مربع البحث
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // مسافة داخلية
            child: TextField(
              controller: _searchController, // وحدة التحكم بحقل البحث
              cursorColor: AppColors.appBarText, // لون مؤشر الكتابة
              style: const TextStyle(color: AppColors.appBarText, fontSize: 16), // تنسيق النص
              decoration: InputDecoration(
                filled: true, // تمكين الخلفية
                fillColor: AppColors.topBackground, // لون الخلفية
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // مسافة داخلية
                labelText: "To: Type names, phone numbers", // نص الإرشاد
                labelStyle: TextStyle(
                  color: AppColors.inputLabel, // لون نص الإرشاد
                  fontSize: 14, // حجم النص
                ),
                border: InputBorder.none, // إزالة الإطار
                suffixIcon: _searchQuery.isNotEmpty // إذا كان هناك نص مكتوب
                    ? IconButton(
                        icon: const Icon(Icons.clear), // أيقونة الحذف
                        onPressed: () {
                          _searchController.clear(); // مسح النص
                          _filterContacts(""); // إعادة تعيين قائمة جهات الاتصال
                        },
                        color: AppColors.inputLabel, // لون الأيقونة
                      )
                    : null, // إذا لم يكن هناك نص، لا يتم عرض الأيقونة
              ),
              onChanged: _filterContacts, // استدعاء دالة الفلترة عند تغيير النص
            ),
          ),
          // قائمة جهات الاتصال
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(), // تأثير التمرير
              itemCount: groupedContacts.length + (_searchQuery.isNotEmpty ? 1 : 0), // عدد العناصر
              itemBuilder: (context, index) {
                if (_searchQuery.isNotEmpty && index == 0) {
                  // خيار إرسال الرقم المكتوب
                  return ListTile(
                    leading: const Icon(Icons.person, color: Colors.blueGrey), // أيقونة الشخص
                    title: Text(
                      "Send to $_searchQuery", // النص المعروض
                      style: const TextStyle(
                        color: AppColors.appBarText, // لون النص
                        fontWeight: FontWeight.w500, // وزن النص متوسط
                      ),
                    ),
                    subtitle: Text(
                      _searchQuery, // الرقم المكتوب
                      style: TextStyle(color: AppColors.inputLabel), // لون النص
                    ),
                    onTap: () async {
                      bool exists = await _isConversationExists(_searchQuery); // التحقق من وجود المحادثة
                      String addressToUse = _searchQuery; // تعيين العنوان الافتراضي
                      if (exists) { // إذا كانت المحادثة موجودة
                        String? existingKey = await _getExistingConversationKey(_searchQuery); // الحصول على المفتاح
                        if (existingKey != null) {
                          addressToUse = existingKey; // استخدام المفتاح الموجود
                        }
                      }
                      // الانتقال إلى شاشة المحادثة
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            address: addressToUse, // العنوان المستخدم
                            recipient: _searchQuery, // الرقم المكتوب
                          ),
                        ),
                      );
                    },
                  );
                }

                // عرض جهة الاتصال
                final contact = groupedContacts[_searchQuery.isNotEmpty ? index - 1 : index];
                final displayName = contact.displayName.trim(); // اسم جهة الاتصال
                final phoneNumber = contact.phones.isNotEmpty
                    ? contact.phones.first.number // رقم الهاتف الأول
                    : "";

                return ListTile(
                  leading: CircleAvatar(
                    radius: 20, // نصف قطر الصورة
                    backgroundColor: _getAvatarBackgroundColor(displayName), // لون الخلفية
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', // الحرف الأول من الاسم
                      style: const TextStyle(
                        color: Colors.white, // لون النص
                        fontWeight: FontWeight.bold, // وزن النص عريض
                      ),
                    ),
                  ),
                  title: Text(
                    displayName, // اسم جهة الاتصال
                    style: const TextStyle(
                      color: AppColors.appBarText, // لون النص
                      fontWeight: FontWeight.w500, // وزن النص متوسط
                    ),
                  ),
                  subtitle: Text(
                    phoneNumber.isNotEmpty ? phoneNumber : "No phone number", // عرض رقم الهاتف أو رسالة بديلة
                    style: TextStyle(color: AppColors.inputLabel), // لون النص
                  ),
                  onTap: () async {
                    if (phoneNumber.isNotEmpty) { // التحقق من وجود رقم الهاتف
                      bool exists = await _isConversationExists(phoneNumber); // التحقق من وجود المحادثة
                      String addressToUse = phoneNumber; // تعيين العنوان الافتراضي
                      if (exists) { // إذا كانت المحادثة موجودة
                        String? existingKey = await _getExistingConversationKey(phoneNumber); // الحصول على المفتاح
                        if (existingKey != null) {
                          addressToUse = existingKey; // استخدام المفتاح الموجود
                        }
                      }
                      // الانتقال إلى شاشة المحادثة
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            address: addressToUse, // العنوان المستخدم
                            recipient: displayName, // اسم جهة الاتصال
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}